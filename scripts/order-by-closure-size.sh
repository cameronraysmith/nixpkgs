#!/usr/bin/env bash
# Order packages by closure size (proxy for dependency depth)
# Packages with smaller closures have fewer dependencies and should build first
set -euo pipefail

PACKAGE_LIST="${1:-duckdb-packages-list.txt}"
SYSTEM="${2:-aarch64-linux}"
OUTPUT="${3:-ordered-packages.txt}"

if [ ! -f "$PACKAGE_LIST" ]; then
    echo "Error: Package list not found: $PACKAGE_LIST"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Ordering packages by dependency depth (closure size)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "System: $SYSTEM"
echo "Input: $PACKAGE_LIST ($(wc -l < "$PACKAGE_LIST") packages)"
echo "Output: $OUTPUT"
echo ""

TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

TOTAL=$(wc -l < "$PACKAGE_LIST")
CURRENT=0

echo "Analyzing package closures (this may take 5-10 minutes)..."
echo ""
echo "Note: Using derivation analysis (fast, no builds required)"
echo ""

while IFS= read -r pkg; do
    ((CURRENT++)) || true

    # Show progress every package for better feedback
    printf "\r[%3d/%3d] Analyzing: %-50s" "$CURRENT" "$TOTAL" "$pkg"

    # Strategy: Count derivation inputs as a proxy for closure size
    # This is fast (no builds) and correlates well with dependency depth
    # We query the derivation (.drv) and count its inputs
    # Note: nixpkgs uses legacyPackages, not packages

    # Disable pipefail temporarily to handle errors gracefully
    set +e
    DRV_PATH=$(nix eval --raw ".#legacyPackages.$SYSTEM.$pkg.drvPath" 2>/dev/null)
    EVAL_EXIT=$?
    set -e

    if [ $EVAL_EXIT -eq 0 ] && [ -n "$DRV_PATH" ]; then
        # Count number of input derivations (dependencies)
        INPUT_COUNT=$(nix-store --query --references "$DRV_PATH" 2>/dev/null | wc -l | tr -d ' ')

        # Default to high number if count failed
        if [ -z "$INPUT_COUNT" ] || [ "$INPUT_COUNT" = "0" ]; then
            INPUT_COUNT=9999
        fi

        # Use input count as proxy for depth (padded for sorting)
        # Format: 00000000123 package_name
        printf "%011d %s\n" "$INPUT_COUNT" "$pkg" >> "$TEMP_FILE"
    else
        # If we can't determine (broken package, etc), put at end
        echo "99999999999 $pkg" >> "$TEMP_FILE"
    fi
done < "$PACKAGE_LIST"

echo ""  # New line after progress

echo ""
echo ""

# Sort by closure size (smallest first) and extract package names
sort -n "$TEMP_FILE" | awk '{print $2}' > "$OUTPUT"

echo "✓ Packages ordered by dependency depth"
echo ""

# Show statistics
echo "Dependency depth distribution:"
echo ""

# Show first 5 (shallowest dependencies)
echo "Shallowest dependencies (build first):"
head -5 "$OUTPUT" | while IFS= read -r pkg; do
    INPUT_COUNT=$(grep " $pkg$" "$TEMP_FILE" | awk '{print $1}')
    # Strip leading zeros for display
    INPUT_COUNT=$((10#$INPUT_COUNT))
    if [ "$INPUT_COUNT" = "99999999999" ]; then
        echo "  $pkg (analysis failed)"
    else
        echo "  $pkg ($INPUT_COUNT direct dependencies)"
    fi
done

echo ""

# Show last 5 (deepest dependencies)
echo "Deepest dependencies (build last):"
tail -5 "$OUTPUT" | while IFS= read -r pkg; do
    INPUT_COUNT=$(grep " $pkg$" "$TEMP_FILE" | awk '{print $1}')
    INPUT_COUNT=$((10#$INPUT_COUNT))
    if [ "$INPUT_COUNT" = "99999999999" ]; then
        echo "  $pkg (analysis failed - will try anyway)"
    else
        echo "  $pkg ($INPUT_COUNT direct dependencies)"
    fi
done

echo ""
echo "Ordered package list written to: $OUTPUT"
echo ""
echo "Next step:"
echo "  ./scripts/review-linux-orchestrated.sh duckdb-132-140 master $OUTPUT"
