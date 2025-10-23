# Finding Transitive Dependencies for nixpkgs-review

This guide explains how to use `find-transitive-deps.sh` to systematically exclude packages that depend on problematic build dependencies (like `sbcl` on Darwin).

## Quick Start

```bash
cd ~/projects/nixpkgs

# 1. First, run nixpkgs-review to generate evaluation cache (dry-run is fine)
nixpkgs-review rev update-duckdb-1.4-review \
  --branch master \
  --systems aarch64-darwin \
  --build-args '--dry-run'

# 2. Find all packages depending on sbcl
./scripts/find-transitive-deps.sh --target sbcl --verbose

# 3. Copy the generated -P flags and use them in your actual build
```

## Step-by-Step Workflow

### 1. Generate the Evaluation Cache

nixpkgs-review must evaluate the diff first to create `attrs.nix`:

```bash
nixpkgs-review rev <your-branch> \
  --branch <base-branch> \
  --systems <target-system> \
  --build-args '--dry-run'
```

The `--dry-run` flag makes this fast - it evaluates but doesn't build.

### 2. Run Dependency Analysis

Basic usage (finds sbcl dependencies for current branch):

```bash
./scripts/find-transitive-deps.sh
```

With options:

```bash
./scripts/find-transitive-deps.sh \
  --target sbcl \
  --branch update-duckdb-1.4-review \
  --base master \
  --system aarch64-darwin \
  --verbose
```

### 3. Use the Output

The script outputs `-P package1 -P package2 ...` flags that you can directly use:

```bash
# Copy the output and paste into your nixpkgs-review command
nixpkgs-review rev update-duckdb-1.4-review \
  --branch master \
  --systems aarch64-darwin \
  -P python312Packages.wandb -P python313Packages.wandb \
  -P python312Packages.plotly -P python313Packages.plotly \
  # ... (all the packages the script found)
```

## Output Formats

### `--format flags` (default)

Outputs space-separated `-P` flags for nixpkgs-review:

```
-P python312Packages.wandb -P python313Packages.plotly -P coqui-tts
```

### `--format list`

One package per line (useful for further processing):

```
python312Packages.wandb
python313Packages.plotly
coqui-tts
```

### `--format json`

JSON array with dependency information:

```json
[
  {"package": "python312Packages.wandb"},
  {"package": "python313Packages.plotly"},
  {"package": "coqui-tts"}
]
```

## Advanced Usage

### Find Multiple Dependencies

```bash
# Find all packages depending on sbcl
./scripts/find-transitive-deps.sh --target sbcl > sbcl-deps.txt

# Find all packages depending on llvm
./scripts/find-transitive-deps.sh --target llvm > llvm-deps.txt

# Combine for exclusion
cat sbcl-deps.txt llvm-deps.txt
```

### Iterative Workflow

If you're still hitting the unwanted dependency after exclusions:

```bash
# 1. Run with verbose to see which packages still depend on it
./scripts/find-transitive-deps.sh --target sbcl --verbose 2>&1 | tee analysis.log

# 2. Review the dependency chains shown
grep "DEPENDS on" analysis.log

# 3. Add newly discovered packages to exclusion list
```

### Script into Your Build Process

```bash
#!/usr/bin/env bash
set -euo pipefail

BRANCH="update-duckdb-1.4-review"
BASE="master"
SYSTEM="aarch64-darwin"

# Generate exclusions dynamically
EXCLUSIONS=$(./scripts/find-transitive-deps.sh \
  --target sbcl \
  --branch "$BRANCH" \
  --base "$BASE" \
  --system "$SYSTEM" \
  --format flags)

# Run nixpkgs-review with generated exclusions
nixpkgs-review rev "$BRANCH" \
  --branch "$BASE" \
  --systems "$SYSTEM" \
  $EXCLUSIONS \
  --no-shell
```

## Understanding the Output

When run with `--verbose`, you'll see:

```
[INFO] Configuration:
[INFO]   Target dependency: sbcl
[INFO]   Branch: update-duckdb-1.4-review
[INFO]   Base: master
[INFO]   System: aarch64-darwin
[SUCCESS] Found cached evaluation at ~/.cache/nixpkgs-review/rev-307f27d5/attrs.nix
[INFO] Found 340 changed packages
[INFO] Analyzing dependency closures...
[1/340] Checking: python312Packages.wandb
[INFO]   ✓ DEPENDS on sbcl
    python312Packages.wandb
    → python312Packages.plotly
    → python312Packages.kaleido
    → sbcl
[2/340] Checking: python312Packages.duckdb
[INFO]   ○ No dependency
...

[SUCCESS] Analysis complete
Summary:
  Changed packages analyzed: 340
  Packages depending on sbcl: 47

To exclude these from nixpkgs-review, add these flags:
-P python312Packages.wandb -P python313Packages.plotly ...
```

## How It Works (Conceptually Pure Approach)

1. **Reads nixpkgs-review's evaluation**: Uses the cached `attrs.nix` that contains all changed packages

2. **For each changed package**:
   - Instantiates the derivation: `nix-instantiate -A <package>`
   - Queries the full dependency closure: `nix-store --query --requisites --include-outputs`
   - Checks if target package appears in closure

3. **Uses Nix's fundamental operations**:
   - No heuristics or pattern matching
   - Queries the actual dependency DAG
   - Works for any package, any system, any diff

## Troubleshooting

### "No cached evaluation found"

You need to run nixpkgs-review first:

```bash
nixpkgs-review rev <branch> --branch <base> --build-args '--dry-run'
```

### "Cannot instantiate target package"

The target package doesn't exist or can't build for the specified system:

```bash
# Check if package exists
nix-instantiate -A sbcl --argstr system aarch64-darwin
```

### Script is slow

The script queries the dependency closure for each changed package. For 340 packages, this can take 5-10 minutes. Use `--verbose` to see progress.

### Still building unwanted dependency

1. Run the script again - new transitive dependencies may have appeared
2. Check if you're using the correct branch/base
3. Verify the nixpkgs-review cache is up to date

## Examples

### Example 1: Exclude sbcl dependencies

```bash
# Generate exclusion list
./scripts/find-transitive-deps.sh --target sbcl --format flags > /tmp/sbcl-exclusions.txt

# Use in build
nixpkgs-review rev update-duckdb-1.4-review \
  --branch master \
  --systems aarch64-darwin \
  $(cat /tmp/sbcl-exclusions.txt) \
  --no-shell
```

### Example 2: Compare dependencies between branches

```bash
# Check what depends on llvm in current branch
./scripts/find-transitive-deps.sh --target llvm --format list > branch-llvm.txt

# Switch branches and compare
git checkout other-branch
nixpkgs-review rev other-branch --build-args '--dry-run'
./scripts/find-transitive-deps.sh --target llvm --format list > other-llvm.txt

# Find differences
diff branch-llvm.txt other-llvm.txt
```

### Example 3: Automated exclusion in wrapper script

```bash
#!/usr/bin/env bash
# save as: scripts/review-excluding-sbcl.sh

set -euo pipefail

# Find sbcl dependencies automatically
SBCL_EXCLUSIONS=$(./scripts/find-transitive-deps.sh \
  --target sbcl \
  --format flags \
  --system aarch64-darwin)

# Run review with cachix
cd ~/projects/nix-workspace/nix-config
sops exec-env secrets/shared.yaml "
  cd ~/projects/nixpkgs
  cachix watch-exec \$CACHIX_CACHE_NAME --jobs 12 -- \
    nixpkgs-review rev update-duckdb-1.4-review \
      --branch master \
      --systems aarch64-darwin \
      --num-parallel-evals 12 \
      --build-args '--max-jobs 12 --cores 12 --keep-going' \
      $SBCL_EXCLUSIONS \
      --no-shell
"
```

## Theory: Why This Works

This approach is based on Nix's fundamental properties:

1. **Content-addressed store**: Every derivation's output path is determined by hashing its inputs. If package A depends on package B, and B's inputs change, then A's output path changes too.

2. **Explicit dependency graph**: Nix derivations explicitly declare their dependencies via `buildInputs`, `propagatedBuildInputs`, etc. This forms a DAG.

3. **Transitive closure**: `nix-store --query --requisites` computes the mathematical transitive closure of the dependency relation. If A → B → C, then C ∈ closure(A).

4. **nixpkgs-review's diff**: It compares output paths between two evaluations. Any package whose transitive inputs changed will have a different output path.

Therefore, querying `closure(changed_package) ∩ {target}` is both necessary and sufficient to determine if `changed_package` transitively depends on `target`.
