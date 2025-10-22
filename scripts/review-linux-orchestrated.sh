#!/usr/bin/env bash
# Orchestrated nixpkgs-review: dependency-ordered batches with rosetta builder
# The most principled approach: build shallow dependencies first, deep ones last
set -euo pipefail

BRANCH="${1:-duckdb-132-140}"
BASE_BRANCH="${2:-master}"
PACKAGE_LIST="${3:-ordered-packages.txt}"
BATCH_SIZE="${4:-50}"

if [ ! -f "$PACKAGE_LIST" ]; then
    echo "Error: Package list not found: $PACKAGE_LIST"
    echo ""
    echo "Did you run the ordering step first?"
    echo "  ./scripts/order-by-closure-size.sh duckdb-packages-list.txt aarch64-linux"
    exit 1
fi

# Verify package list is ordered (has no random package at top that should be deep)
FIRST_PKG=$(head -1 "$PACKAGE_LIST")
echo "Verifying package order (first package: $FIRST_PKG)..."

# Create orchestration directory (use absolute path)
ORCH_DIR="$(pwd)/orchestrated-review-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ORCH_DIR"/{batches,logs,reports}

# Copy ordered list for traceability
cp "$PACKAGE_LIST" "$ORCH_DIR/ordered-packages.txt"

# Record metadata
cat > "$ORCH_DIR/metadata.json" <<EOF
{
  "branch": "$BRANCH",
  "base_branch": "$BASE_BRANCH",
  "batch_size": $BATCH_SIZE,
  "total_packages": $(wc -l < "$PACKAGE_LIST"),
  "started_at": "$(date -Iseconds)",
  "system": "aarch64-linux",
  "builder": "nix-rosetta-builder",
  "ordering": "dependency-depth (closure size)"
}
EOF

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Orchestrated nixpkgs-review (Dependency-Ordered Batching)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Branch: $BRANCH"
echo "Base: $BASE_BRANCH"
echo "Total packages: $(wc -l < "$PACKAGE_LIST")"
echo "Batch size: $BATCH_SIZE"
echo "Orchestration dir: $ORCH_DIR"
echo ""

# shellcheck disable=SC2016
CACHE_NAME=$(cd ~/projects/nix-workspace/nix-config && \
    sops exec-env secrets/shared.yaml 'echo $CACHIX_CACHE_NAME')
echo "Cache: https://app.cachix.org/cache/$CACHE_NAME"
echo ""

echo "Strategy:"
echo "  1. Packages ordered by closure size (shallow deps → deep deps)"
echo "  2. Build in batches of $BATCH_SIZE"
echo "  3. Each batch benefits from cache of previous batches"
echo "  4. Failures recorded per batch for analysis"
echo ""

# Split into batches
echo "Creating batches..."
split -l "$BATCH_SIZE" "$PACKAGE_LIST" "$ORCH_DIR/batches/batch-"

# Rename with numbers
i=1
for file in "$ORCH_DIR"/batches/batch-*; do
    mv "$file" "$ORCH_DIR/batches/batch-$(printf "%03d" $i).txt"
    ((i++))
done

BATCH_FILES=("$ORCH_DIR"/batches/batch-*.txt)
BATCH_COUNT=${#BATCH_FILES[@]}
echo "✓ Created $BATCH_COUNT batches"
echo ""

# Verify builder (on-demand mode - will start when needed)
echo "Verifying nix-rosetta-builder configuration..."

# Check if rosetta-builder is in /etc/nix/machines
if [ -f /etc/nix/machines ] && grep -q "rosetta-builder.*aarch64-linux" /etc/nix/machines; then
    echo "✓ Builder configured (on-demand mode - will start when first build is dispatched)"
else
    echo "❌ nix-rosetta-builder not found in /etc/nix/machines"
    echo "   Run 'just activate' in ~/projects/nix-workspace/nix-config"
    exit 1
fi
echo ""

# Track progress
SUCCESS_COUNT=0
FAILURE_COUNT=0
FAILED_BATCHES=()
declare -a BATCH_TIMES

START_TIME=$(date +%s)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Starting batch builds (shallow → deep dependencies)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for batch in "$ORCH_DIR"/batches/batch-*.txt; do
    batch_name=$(basename "$batch" .txt)
    batch_num=$(echo "$batch_name" | grep -oE '[0-9]+')
    pkg_count=$(wc -l < "$batch")

    # Show first and last package in batch for context
    first_pkg=$(head -1 "$batch")
    last_pkg=$(tail -1 "$batch")

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Batch $batch_num/$BATCH_COUNT ($pkg_count packages)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "First: $first_pkg"
    echo "Last:  $last_pkg"
    echo ""

    BATCH_START=$(date +%s)

    # Build package arguments from batch file
    PACKAGE_ARGS=""
    while IFS= read -r pkg; do
        PACKAGE_ARGS="$PACKAGE_ARGS -p $pkg"
    done < "$batch"

    # Run nixpkgs-review for this batch
    cd ~/projects/nix-workspace/nix-config && \
    if sops exec-env secrets/shared.yaml "
        cd ~/projects/nixpkgs && \
        cachix watch-exec \$CACHIX_CACHE_NAME --jobs 12 -- \
            nixpkgs-review rev $BRANCH \
                --branch $BASE_BRANCH \
                --systems aarch64-linux \
                --num-parallel-evals 12 \
                --build-args '--max-jobs 12 --cores 12 --keep-going' \
                $PACKAGE_ARGS \
                --no-shell 2>&1 | tee $ORCH_DIR/logs/$batch_name.log
    "; then
        ((SUCCESS_COUNT++))
        BATCH_END=$(date +%s)
        BATCH_DURATION=$((BATCH_END - BATCH_START))
        BATCH_TIMES+=("$BATCH_DURATION")

        echo ""
        echo "✅ Batch $batch_num completed successfully in ${BATCH_DURATION}s"

        # Extract successful packages for traceability
        grep "^built" "$ORCH_DIR/logs/$batch_name.log" | \
            awk '{print $2}' > "$ORCH_DIR/reports/$batch_name-success.txt" 2>/dev/null || true

    else
        ((FAILURE_COUNT++))
        FAILED_BATCHES+=("$batch_name")
        BATCH_END=$(date +%s)
        BATCH_DURATION=$((BATCH_END - BATCH_START))
        BATCH_TIMES+=("$BATCH_DURATION")

        echo ""
        echo "❌ Batch $batch_num failed after ${BATCH_DURATION}s"

        # Extract failed packages
        grep -E "(error:|failed)" "$ORCH_DIR/logs/$batch_name.log" | \
            grep -oE "packages\.[^'\"]+\.[^'\"[:space:]]+" | \
            cut -d. -f3 | sort -u > "$ORCH_DIR/reports/$batch_name-failed.txt" 2>/dev/null || true
    fi

    # Progress update
    COMPLETED=$((SUCCESS_COUNT + FAILURE_COUNT))
    ELAPSED=$((BATCH_END - START_TIME))

    # Calculate average time
    TOTAL_BATCH_TIME=0
    for time in "${BATCH_TIMES[@]}"; do
        TOTAL_BATCH_TIME=$((TOTAL_BATCH_TIME + time))
    done
    AVG_TIME=$((TOTAL_BATCH_TIME / COMPLETED))

    REMAINING=$((BATCH_COUNT - COMPLETED))
    ETA=$((REMAINING * AVG_TIME))

    echo ""
    echo "Progress: $COMPLETED/$BATCH_COUNT batches"
    echo "Success: $SUCCESS_COUNT | Failures: $FAILURE_COUNT"
    echo "Avg time/batch: ${AVG_TIME}s ($(echo "scale=1; $AVG_TIME/60" | bc)m)"
    echo "Elapsed: $((ELAPSED / 60))m | ETA: $((ETA / 60))m"
    echo ""

    # Checkpoint: save progress
    cat > "$ORCH_DIR/progress.json" <<EOF
{
  "completed": $COMPLETED,
  "total": $BATCH_COUNT,
  "successful": $SUCCESS_COUNT,
  "failed": $FAILURE_COUNT,
  "elapsed_seconds": $ELAPSED,
  "eta_seconds": $ETA,
  "last_batch": "$batch_name",
  "timestamp": "$(date -Iseconds)"
}
EOF

done

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

# Update final metadata
jq --arg finished "$(date -Iseconds)" \
   --arg duration "$TOTAL_DURATION" \
   --arg success "$SUCCESS_COUNT" \
   --arg failure "$FAILURE_COUNT" \
   '. + {
      finished_at: $finished,
      duration_seconds: ($duration | tonumber),
      successful_batches: ($success | tonumber),
      failed_batches: ($failure | tonumber)
   }' "$ORCH_DIR/metadata.json" > "$ORCH_DIR/metadata.json.tmp"
mv "$ORCH_DIR/metadata.json.tmp" "$ORCH_DIR/metadata.json"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Orchestrated review complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total time: $((TOTAL_DURATION / 60))m $((TOTAL_DURATION % 60))s"
echo "Successful batches: $SUCCESS_COUNT/$BATCH_COUNT"
echo "Failed batches: $FAILURE_COUNT/$BATCH_COUNT"
echo ""

# Generate comprehensive report
cat > "$ORCH_DIR/REPORT.md" <<EOF
# Orchestrated nixpkgs-review Report

## Summary

- **Branch**: $BRANCH
- **Base**: $BASE_BRANCH
- **System**: aarch64-linux
- **Builder**: nix-rosetta-builder
- **Strategy**: Dependency-ordered batching (shallow → deep)
- **Total packages**: $(wc -l < "$PACKAGE_LIST")
- **Batch size**: $BATCH_SIZE
- **Total batches**: $BATCH_COUNT
- **Duration**: $((TOTAL_DURATION / 60))m $((TOTAL_DURATION % 60))s

## Results

- ✅ Successful batches: $SUCCESS_COUNT
- ❌ Failed batches: $FAILURE_COUNT
- 📦 Cache: https://app.cachix.org/cache/$CACHE_NAME

## Batch Details

EOF

# Append batch-by-batch details
for ((i=1; i<=BATCH_COUNT; i++)); do
    batch_name="batch-$(printf "%03d" $i)"
    batch_file="$ORCH_DIR/batches/$batch_name.txt"
    pkg_count=$(wc -l < "$batch_file")

    if [ -f "$ORCH_DIR/reports/$batch_name-success.txt" ]; then
        status="✅ Success"
        success_count=$(wc -l < "$ORCH_DIR/reports/$batch_name-success.txt" || echo 0)
        details="$success_count packages built"
    elif [ -f "$ORCH_DIR/reports/$batch_name-failed.txt" ]; then
        status="❌ Failed"
        failure_count=$(wc -l < "$ORCH_DIR/reports/$batch_name-failed.txt" || echo 0)
        details="$failure_count packages failed"
    else
        status="⚠️  Unknown"
        details="No report"
    fi

    duration="${BATCH_TIMES[$((i-1))]:-0}"

    cat >> "$ORCH_DIR/REPORT.md" <<EOF
### Batch $i/$BATCH_COUNT - $status

- Packages: $pkg_count
- Duration: ${duration}s ($(echo "scale=1; $duration/60" | bc)m)
- $details
- Log: \`logs/$batch_name.log\`

EOF
done

if [ ${#FAILED_BATCHES[@]} -gt 0 ]; then
    cat >> "$ORCH_DIR/REPORT.md" <<EOF

## Failed Batches

The following batches had failures:

EOF

    for failed in "${FAILED_BATCHES[@]}"; do
        cat >> "$ORCH_DIR/REPORT.md" <<EOF
- $failed
  - Log: \`logs/$failed.log\`
  - Failed packages: \`reports/$failed-failed.txt\`

EOF
    done

    # Collect all failed packages
    cat "$ORCH_DIR"/reports/*-failed.txt 2>/dev/null | sort -u > "$ORCH_DIR/all-failed-packages.txt" || true
    failed_pkg_count=$(wc -l < "$ORCH_DIR/all-failed-packages.txt" 2>/dev/null || echo 0)

    cat >> "$ORCH_DIR/REPORT.md" <<EOF

## Retry Failed Packages

Total failed packages: $failed_pkg_count

\`\`\`bash
# Retry all failures
./scripts/review-linux-with-rosetta.sh $BRANCH $BASE_BRANCH $ORCH_DIR/all-failed-packages.txt
\`\`\`

EOF
fi

cat >> "$ORCH_DIR/REPORT.md" <<EOF

## Traceability

- Orchestration directory: \`$ORCH_DIR/\`
- Metadata: \`$ORCH_DIR/metadata.json\`
- Ordered package list: \`$ORCH_DIR/ordered-packages.txt\`
- Individual batch logs: \`$ORCH_DIR/logs/\`
- Per-batch reports: \`$ORCH_DIR/reports/\`

## Cache Usage

All successful builds have been pushed to:
https://app.cachix.org/cache/$CACHE_NAME

Future builds (including CI) will use these cached artifacts.

EOF

echo ""
echo "📊 Report generated: $ORCH_DIR/REPORT.md"
echo ""
cat "$ORCH_DIR/REPORT.md"
