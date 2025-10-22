#!/usr/bin/env bash
# Order packages by dependency depth for incremental building
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <package-list-file> [system]"
    echo "Example: $0 duckdb-packages-list.txt aarch64-darwin"
    exit 1
fi

PACKAGE_LIST="$1"
SYSTEM="${2:-aarch64-darwin}"
OUTPUT_DIR="batches"

mkdir -p "$OUTPUT_DIR"

# Function to get runtime dependencies count (rough proxy for depth)
get_dep_count() {
    local pkg="$1"
    nix-instantiate --eval --strict -A "$pkg" \
        --argstr system "$SYSTEM" \
        --expr "with import ./. {}; (builtins.length (lib.attrNames ($pkg.propagatedBuildInputs or [])) + builtins.length (lib.attrNames ($pkg.buildInputs or [])))" 2>/dev/null || echo "999"
}

echo "Analyzing dependency depths..."

# Create associative array for package depths
declare -A pkg_depths

while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    depth=$(get_dep_count "$pkg")
    pkg_depths["$pkg"]="$depth"
    echo "$pkg: $depth deps"
done < "$PACKAGE_LIST"

# Sort packages by depth (fewest deps first)
for pkg in "${!pkg_depths[@]}"; do
    echo "${pkg_depths[$pkg]} $pkg"
done | sort -n | cut -d' ' -f2- > "$OUTPUT_DIR/ordered-packages.txt"

# Split into batches of 50
split -l 50 "$OUTPUT_DIR/ordered-packages.txt" "$OUTPUT_DIR/batch-"

echo "Created batches in $OUTPUT_DIR/"
ls -1 "$OUTPUT_DIR"/batch-* | wc -l | xargs echo "Total batches:"
