#!/usr/bin/env bash
# Extract failed packages from nixpkgs-review output for retry
set -euo pipefail

REVIEW_DIR="${1:-$HOME/.cache/nixpkgs-review}"
OUTPUT_FILE="${2:-failed-packages.txt}"

if [ ! -d "$REVIEW_DIR" ]; then
    echo "Error: Review directory not found: $REVIEW_DIR"
    exit 1
fi

echo "Extracting failed packages from $REVIEW_DIR..."
echo ""

# Find the most recent review (use find instead of ls for robustness)
LATEST_REVIEW=$(find "$REVIEW_DIR" -maxdepth 1 -type d -name "rev-*" -print0 2>/dev/null | \
    xargs -0 ls -dt 2>/dev/null | head -1 || echo "")

if [ -z "$LATEST_REVIEW" ]; then
    echo "No review directories found in $REVIEW_DIR"
    exit 1
fi

echo "Latest review: $LATEST_REVIEW"

# Extract failed packages from report.md
if [ -f "$LATEST_REVIEW/report.md" ]; then
    echo "Parsing report.md..."

    # Failed packages appear in sections like:
    # ## Failed builds (15)
    # - `python312Packages.duckdb`
    # - `python313Packages.duckdb`

    awk '
        /^## Failed builds/ { in_failed=1; next }
        /^## / { in_failed=0 }
        in_failed && /^- `/ {
            # Extract package name between backticks
            match($0, /`([^`]+)`/, arr)
            print arr[1]
        }
    ' "$LATEST_REVIEW/report.md" | sort -u > "$OUTPUT_FILE"

    FAILED_COUNT=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')

    if [ "$FAILED_COUNT" -gt 0 ]; then
        echo ""
        echo "✓ Extracted $FAILED_COUNT failed packages to $OUTPUT_FILE"
        echo ""
        echo "Failed packages:"
        cat "$OUTPUT_FILE" | sed 's/^/  - /'
        echo ""
        echo "To retry:"
        echo "  ./scripts/review-linux-with-rosetta.sh BRANCH master $OUTPUT_FILE"
    else
        echo ""
        echo "✓ No failures found! All packages built successfully."
        rm -f "$OUTPUT_FILE"
    fi

    # Also show build statistics from report
    echo ""
    echo "Build statistics:"
    grep -E "^## (Built|Failed|Skipped)" "$LATEST_REVIEW/report.md" || echo "  (statistics not available)"

else
    echo "Error: report.md not found in $LATEST_REVIEW"
    exit 1
fi
