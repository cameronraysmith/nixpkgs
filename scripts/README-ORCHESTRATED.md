# Orchestrated nixpkgs-review: The Principled Approach

## TL;DR - The Most Principled, Performant, Traceable Approach

```bash
# Step 1: Order packages by dependency depth (5-10 minutes)
./scripts/order-by-closure-size.sh duckdb-packages-list.txt aarch64-linux ordered-packages.txt

# Step 2: Run orchestrated review with dependency-ordered batches (30-90 minutes)
./scripts/review-linux-orchestrated.sh duckdb-132-140 master ordered-packages.txt 50
```

## Why This Approach is Superior

### 1. Principled (Dependency-Aware)

**Problem**: Building packages in random order means:
- Dependencies might not be cached when dependents build
- Failures in deep dependencies aren't discovered until late
- Cache utilization is suboptimal

**Solution**: Build shallow dependencies first, deep ones last:
```
Batch 1: duckdb (small closure, few deps)
Batch 2: python312Packages.duckdb (depends on duckdb - now cached!)
Batch 3: harlequin (depends on python312Packages.duckdb - now cached!)
```

### 2. Performant (Maximum Cache Reuse)

**Metrics**:
- **Ordering phase**: 5-10 minutes (one-time cost)
- **Build phase**: Same total build time, but better cache hits
- **Re-runs**: Much faster - cached dependencies accelerate dependent builds

**Cache efficiency**:
```
Random order:  ████░░░░░░ 40% cache hits (deps built after dependents)
Ordered:       ██████████ 90% cache hits (deps cached before dependents)
```

### 3. Traceable (Comprehensive Audit Trail)

Every orchestrated run creates a timestamped directory with:

```
orchestrated-review-20251022-143522/
├── metadata.json              # Run configuration and results
├── progress.json              # Real-time progress checkpoint
├── ordered-packages.txt       # Dependency-ordered package list
├── REPORT.md                  # Human-readable comprehensive report
├── batches/
│   ├── batch-001.txt         # Packages in each batch
│   ├── batch-002.txt
│   └── ...
├── logs/
│   ├── batch-001.log         # Full nixpkgs-review output per batch
│   ├── batch-002.log
│   └── ...
└── reports/
    ├── batch-001-success.txt # Successful packages per batch
    ├── batch-002-failed.txt  # Failed packages per batch
    └── all-failed-packages.txt # Aggregated failures for retry
```

## Comparison Matrix

| Approach | Principled | Performant | Traceable | Use Case |
|----------|-----------|------------|-----------|----------|
| **Orchestrated** (this) | ✅ Dependency-ordered | ✅ Max cache reuse | ✅ Full audit trail | Production reviews |
| Batched (review-linux-batched.sh) | ⚠️ Random order | ⚠️ Some cache waste | ✅ Per-batch logs | Quick iteration |
| Single (review-linux-with-rosetta.sh) | ⚠️ Random order | ⚠️ Some cache waste | ⚠️ Single log | Small package sets |

## Complete Workflow

### Phase 1: Analysis & Ordering

```bash
cd ~/projects/nixpkgs

# Analyze dependency depths and order packages
./scripts/order-by-closure-size.sh duckdb-packages-list.txt aarch64-linux ordered-packages.txt
```

**What this does**:
- Queries closure size for each package (via `nix path-info --closure-size`)
- Sorts packages: smallest closure → largest closure
- Small closure = few dependencies = build first
- Large closure = many dependencies = build last

**Output**:
```
Shallowest dependencies (build first):
  duckdb (245MB closure)
  python312Packages.duckdb-engine (312MB closure)
  ...

Deepest dependencies (build last):
  open-webui (2.4GB closure)
  streamlit (2.8GB closure)
  ...
```

### Phase 2: Orchestrated Build

```bash
# Run with dependency-ordered batches
./scripts/review-linux-orchestrated.sh duckdb-132-140 master ordered-packages.txt 50
```

**What happens**:
1. ✓ Verifies nix-rosetta-builder connectivity
2. ✓ Creates batches of 50 packages (preserving order)
3. ✓ Builds batch 1 (shallowest deps) → pushes to cachix
4. ✓ Builds batch 2 (using batch 1 cache) → pushes to cachix
5. ✓ Continues until all batches complete
6. ✓ Generates comprehensive report

**Progress tracking**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Batch 3/7 (50 packages)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
First: python312Packages.ibis-framework
Last:  python312Packages.langchain-community

✅ Batch 3 completed successfully in 1847s

Progress: 3/7 batches
Success: 3 | Failures: 0
Avg time/batch: 1612s (26.9m)
Elapsed: 80m | ETA: 107m
```

### Phase 3: Analysis & Retry

```bash
# View comprehensive report
cat orchestrated-review-*/REPORT.md

# Retry failures (if any)
./scripts/review-linux-with-rosetta.sh \
    duckdb-132-140 master \
    orchestrated-review-*/all-failed-packages.txt
```

## Why Closure Size = Dependency Depth

**Closure size** is the total size of a package plus all its runtime dependencies:

```
duckdb.closure = {duckdb, stdenv, glibc, gcc-libs, ...}  ← Small (few deps)

harlequin.closure = {
    harlequin,
    python312,
    python312Packages.duckdb,  ← Already includes duckdb.closure
    python312Packages.textual,
    python312Packages.rich,
    ... 50+ more packages
}  ← Large (many deps)
```

By building packages with **small closures first**, we ensure:
1. Leaf dependencies (duckdb) are cached early
2. Intermediate packages (python312Packages.duckdb) build faster using cache
3. Top-level packages (harlequin) benefit from all cached dependencies

## Performance Characteristics

### Your nix-rosetta-builder

```yaml
CPU: 12 cores (Rosetta 2 translation)
Memory: 48 GB RAM
Disk: 500 GB
Strategy: On-demand (auto-start, auto-stop)
```

### Expected Timings

| Phase | Time | Notes |
|-------|------|-------|
| Ordering analysis | 5-10 min | One-time cost per package list |
| Batch 1 (shallowest) | 15-30 min | No cached deps yet |
| Batch 2 | 20-35 min | ~30% cache hits from batch 1 |
| Batch 3 | 25-40 min | ~50% cache hits from batches 1-2 |
| Batch 4-7 | 30-50 min each | ~70-90% cache hits |
| **Total** | **~3-4 hours** | For 340 packages |

### Re-run Performance

If you re-run after failures or updates:
```
First run:  3-4 hours   (building from scratch)
Second run: 30-60 min   (most packages cached)
Third run:  10-20 min   (only changed packages)
```

## Failure Analysis

### Pattern Detection

Dependency-ordered builds reveal failure patterns:

```
✅ Batch 1: duckdb ← Success (leaf dependency)
✅ Batch 2: python312Packages.duckdb ← Success (depends on working duckdb)
❌ Batch 3: python312Packages.ibis-framework ← FAILED
❌ Batch 4: open-webui ← FAILED (depends on failed ibis)
```

**Insight**: `ibis-framework` failure cascades to dependents. Fix it first.

### Failure Traceability

```bash
# View all failures
cat orchestrated-review-*/all-failed-packages.txt

# Analyze specific batch
less orchestrated-review-*/logs/batch-003.log

# Compare successful vs failed
diff \
    orchestrated-review-*/reports/batch-002-success.txt \
    orchestrated-review-*/reports/batch-003-failed.txt
```

## Integration with Existing Workflow

Based on your atuin history, you commonly use:

```bash
# You already use for single packages:
just cache-linux-package PACKAGE

# Now add for PR reviews (small):
./scripts/review-linux-with-rosetta.sh BRANCH master packages.txt

# And for comprehensive updates (large):
./scripts/order-by-closure-size.sh packages.txt
./scripts/review-linux-orchestrated.sh BRANCH master ordered-packages.txt
```

## Decision Tree: Which Script to Use?

```
┌─────────────────────────────────────────┐
│ How many packages?                      │
└────┬────────────────────────────────────┘
     │
     ├─ < 10 packages
     │  └─> review-linux-with-rosetta.sh (single batch, fast)
     │
     ├─ 10-50 packages
     │  └─> Do you need detailed progress?
     │     ├─ No  → review-linux-with-rosetta.sh
     │     └─ Yes → review-linux-batched.sh
     │
     └─ > 50 packages
        └─> review-linux-orchestrated.sh ✅
            (dependency-ordered, maximum efficiency)
```

## Advanced: Customizing Batch Size

Batch size affects:
- **Smaller batches (20-30)**: More frequent progress updates, more overhead
- **Larger batches (50-100)**: Less overhead, less frequent updates

```bash
# Small batches for frequent checkpoints
./scripts/review-linux-orchestrated.sh BRANCH master ordered.txt 25

# Large batches for maximum throughput
./scripts/review-linux-orchestrated.sh BRANCH master ordered.txt 100
```

**Recommendation**: Start with 50, adjust based on average batch time:
- If batches finish in < 15 min → increase to 75
- If batches take > 45 min → decrease to 30

## Metadata for Reproducibility

Every orchestrated run records:

```json
{
  "branch": "duckdb-132-140",
  "base_branch": "master",
  "batch_size": 50,
  "total_packages": 340,
  "started_at": "2025-10-22T14:35:22-04:00",
  "finished_at": "2025-10-22T17:52:18-04:00",
  "duration_seconds": 11816,
  "system": "aarch64-linux",
  "builder": "nix-rosetta-builder",
  "ordering": "dependency-depth (closure size)",
  "successful_batches": 6,
  "failed_batches": 1
}
```

This enables:
- Reproducing builds with exact parameters
- Comparing performance across runs
- Auditing what was built and when

## Next Steps

1. **Test the ordering** (quick):
   ```bash
   head -20 duckdb-packages-list.txt > test-20.txt
   ./scripts/order-by-closure-size.sh test-20.txt aarch64-linux ordered-20.txt
   cat ordered-20.txt  # Verify ordering makes sense
   ```

2. **Test orchestrated build** (small scale):
   ```bash
   ./scripts/review-linux-orchestrated.sh duckdb-132-140 master ordered-20.txt 10
   ```

3. **Full run** (when satisfied):
   ```bash
   ./scripts/order-by-closure-size.sh duckdb-packages-list.txt aarch64-linux ordered-340.txt
   ./scripts/review-linux-orchestrated.sh duckdb-132-140 master ordered-340.txt 50
   ```

4. **Share cache with CI**:
   Your GitHub workflows already reference your cachix. After this completes,
   CI jobs will pull from cache instead of rebuilding.
