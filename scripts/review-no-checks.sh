#!/usr/bin/env bash
# Run nixpkgs-review with checks disabled for faster caching
set -euo pipefail

BRANCH="${1:-duckdb-132-140}"
BASE_BRANCH="${2:-master}"
SYSTEM="${3:-aarch64-darwin}"
PACKAGE_LIST="${4:-duckdb-packages-list.txt}"

if [ ! -f "$PACKAGE_LIST" ]; then
    echo "Error: Package list not found: $PACKAGE_LIST"
    exit 1
fi

OVERLAY_FILE="$(pwd)/no-check-overlay.nix"
if [ ! -f "$OVERLAY_FILE" ]; then
    echo "Error: Overlay file not found: $OVERLAY_FILE"
    echo "This script expects no-check-overlay.nix in the nixpkgs root"
    exit 1
fi

echo "Running nixpkgs-review with checks disabled..."
echo "Branch: $BRANCH"
echo "Base: $BASE_BRANCH"
echo "System: $SYSTEM"
echo "Packages: $(wc -l < "$PACKAGE_LIST")"
echo "Overlay: $OVERLAY_FILE"
echo

# Note: Unfortunately, nixpkgs-review doesn't have a built-in way to pass overlays
# The best we can do is use NIXPKGS_OVERLAYS environment variable
# But that may not work with nixpkgs-review's internal nixpkgs handling

# Alternative: just use --keep-going and accept some test failures
# Then re-run with checks later
echo "WARNING: There's no perfect way to disable checks globally in nixpkgs-review"
echo "Using --keep-going to continue past test failures"
echo

nixpkgs-review rev "$BRANCH" \
    --branch "$BASE_BRANCH" \
    --systems "$SYSTEM" \
    --num-parallel-evals 12 \
    --build-args "--max-jobs 8 --cores 2 --keep-going" \
    $(awk '{print "-p", $0}' "$PACKAGE_LIST") \
    --print-result \
    --no-shell

echo
echo "Build complete!"
