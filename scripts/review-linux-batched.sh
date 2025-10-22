#!/usr/bin/env bash
# Run nixpkgs-review in batches for aarch64-linux with incremental caching
set -euo pipefail

BRANCH="${1:-duckdb-132-140}"
BASE_BRANCH="${2:-master}"
PACKAGE_LIST="${3:-duckdb-packages-list.txt}"
BATCH_SIZE="${4:-50}"

if [ ! -f "$PACKAGE_LIST" ]; then
    echo "Error: Package list not found: $PACKAGE_LIST"
    exit 1
fi

# Create batches directory
BATCHES_DIR="batches-linux"
rm -rf "$BATCHES_DIR"
mkdir -p "$BATCHES_DIR/logs"

# Split into batches
TOTAL=$(wc -l < "$PACKAGE_LIST")
split -l "$BATCH_SIZE" "$PACKAGE_LIST" "$BATCHES_DIR/batch-"

# Rename with numbers
i=1
for file in "$BATCHES_DIR"/batch-*; do
    mv "$file" "$BATCHES_DIR/batch-$(printf "%03d" $i).txt"
    ((i++))
done

BATCH_COUNT=$(ls -1 "$BATCHES_DIR"/batch-*.txt | wc -l)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Batched nixpkgs-review for aarch64-linux"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Branch: $BRANCH"
echo "Base: $BASE_BRANCH"
echo "Total packages: $TOTAL"
echo "Batch size: $BATCH_SIZE"
echo "Total batches: $BATCH_COUNT"
echo ""

CACHE_NAME=$(cd ~/projects/nix-workspace/nix-config && \
    sops exec-env secrets/shared.yaml 'echo $CACHIX_CACHE_NAME')
echo "Cache: https://app.cachix.org/cache/$CACHE_NAME"
echo ""

# Track successes and failures
SUCCESS_COUNT=0
FAILURE_COUNT=0
FAILED_BATCHES=()

START_TIME=$(date +%s)

for batch in "$BATCHES_DIR"/batch-*.txt; do
    batch_name=$(basename "$batch" .txt)
    batch_num=$(echo "$batch_name" | grep -oE '[0-9]+')
    pkg_count=$(wc -l < "$batch")

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Batch $batch_num/$BATCH_COUNT ($pkg_count packages)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    BATCH_START=$(date +%s)

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
                $(awk '{print "-p", $0}' "$batch") \
                --print-result \
                --no-shell 2>&1 | tee $BATCHES_DIR/logs/$batch_name.log
    "; then
        ((SUCCESS_COUNT++))
        BATCH_END=$(date +%s)
        BATCH_DURATION=$((BATCH_END - BATCH_START))
        echo "✅ Batch $batch_num completed successfully in ${BATCH_DURATION}s"
    else
        ((FAILURE_COUNT++))
        FAILED_BATCHES+=("$batch_name")
        BATCH_END=$(date +%s)
        BATCH_DURATION=$((BATCH_END - BATCH_START))
        echo "❌ Batch $batch_num failed after ${BATCH_DURATION}s"
    fi

    # Progress update
    COMPLETED=$((SUCCESS_COUNT + FAILURE_COUNT))
    ELAPSED=$((BATCH_END - START_TIME))
    AVG_TIME=$((ELAPSED / COMPLETED))
    REMAINING=$((BATCH_COUNT - COMPLETED))
    ETA=$((REMAINING * AVG_TIME))

    echo ""
    echo "Progress: $COMPLETED/$BATCH_COUNT batches"
    echo "Success: $SUCCESS_COUNT | Failures: $FAILURE_COUNT"
    echo "Avg time/batch: ${AVG_TIME}s | ETA: $((ETA / 60))m"
done

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Batch review complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total time: $((TOTAL_DURATION / 60))m $((TOTAL_DURATION % 60))s"
echo "Successful batches: $SUCCESS_COUNT/$BATCH_COUNT"
echo "Failed batches: $FAILURE_COUNT/$BATCH_COUNT"
echo ""

if [ ${#FAILED_BATCHES[@]} -gt 0 ]; then
    echo "Failed batches:"
    for failed in "${FAILED_BATCHES[@]}"; do
        echo "  - $failed"
        echo "    Log: $BATCHES_DIR/logs/$failed.log"
    done
    echo ""
    echo "To retry failures:"
    echo "  cat $BATCHES_DIR/batch-*.txt > failed-packages.txt"
    echo "  ./scripts/review-linux-with-rosetta.sh $BRANCH $BASE_BRANCH failed-packages.txt"
fi

echo ""
echo "Cache: https://app.cachix.org/cache/$CACHE_NAME"
echo "Logs: $BATCHES_DIR/logs/"
