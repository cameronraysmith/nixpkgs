#!/usr/bin/env bash
# Create batches for incremental nixpkgs-review builds
set -euo pipefail

PACKAGE_LIST="${1:-duckdb-packages-list.txt}"
BATCH_SIZE="${2:-50}"
OUTPUT_DIR="batches"

if [ ! -f "$PACKAGE_LIST" ]; then
    echo "Error: Package list file not found: $PACKAGE_LIST"
    exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Count total packages
TOTAL=$(wc -l < "$PACKAGE_LIST")
echo "Splitting $TOTAL packages into batches of $BATCH_SIZE..."

# Split into batches
split -l "$BATCH_SIZE" "$PACKAGE_LIST" "$OUTPUT_DIR/batch-"

# Rename with numbers for clarity
i=1
for file in "$OUTPUT_DIR"/batch-*; do
    mv "$file" "$OUTPUT_DIR/batch-$(printf "%03d" $i).txt"
    ((i++))
done

BATCH_COUNT=$(ls -1 "$OUTPUT_DIR"/batch-*.txt | wc -l)
echo "Created $BATCH_COUNT batches in $OUTPUT_DIR/"

# Create a runner script
cat > "$OUTPUT_DIR/run-all-batches.sh" <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail

BRANCH="${1:-duckdb-132-140}"
BASE_BRANCH="${2:-master}"
SYSTEM="${3:-aarch64-darwin}"

echo "Running nixpkgs-review for all batches..."
echo "Branch: $BRANCH"
echo "Base: $BASE_BRANCH"
echo "System: $SYSTEM"
echo

for batch in batches/batch-*.txt; do
    batch_name=$(basename "$batch" .txt)
    echo "=========================================="
    echo "Processing $batch_name ($(wc -l < "$batch") packages)"
    echo "=========================================="

    nixpkgs-review rev "$BRANCH" \
        --branch "$BASE_BRANCH" \
        --systems "$SYSTEM" \
        --num-parallel-evals 12 \
        --build-args "--max-jobs 8 --cores 2" \
        $(awk '{print "-p", $0}' "$batch") \
        --print-result \
        --no-shell

    echo "Completed $batch_name"
    echo
done

echo "All batches completed!"
RUNNER

chmod +x "$OUTPUT_DIR/run-all-batches.sh"
echo "Run with: $OUTPUT_DIR/run-all-batches.sh [branch] [base-branch] [system]"
