#!/usr/bin/env bash
# Run nixpkgs-review for aarch64-linux using nix-rosetta-builder and push to cachix
set -euo pipefail

BRANCH="${1:-duckdb-132-140}"
BASE_BRANCH="${2:-master}"
PACKAGE_LIST="${3:-}"  # Optional: if empty/auto, let nixpkgs-review auto-detect
SKIP_PACKAGES="${4:-}"  # Optional: comma-separated list of packages to skip

# Validate package list if provided
if [ -n "$PACKAGE_LIST" ] && [ "$PACKAGE_LIST" != "auto" ] && [ ! -f "$PACKAGE_LIST" ]; then
    echo "Error: Package list not found: $PACKAGE_LIST"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "nixpkgs-review for aarch64-linux via nix-rosetta-builder"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Branch: $BRANCH"
echo "Base: $BASE_BRANCH"
if [ -n "$PACKAGE_LIST" ] && [ "$PACKAGE_LIST" != "auto" ]; then
    echo "Packages: $(grep -cv '^[[:space:]]*\(#\|$\)' "$PACKAGE_LIST") (from $PACKAGE_LIST)"
else
    echo "Packages: auto-detect (all changed packages)"
fi
echo ""

# Get cachix cache name from nix-config
# shellcheck disable=SC2016
CACHE_NAME=$(cd ~/projects/nix-workspace/nix-config && \
    sops exec-env secrets/shared.yaml 'echo $CACHIX_CACHE_NAME')
echo "Cache: https://app.cachix.org/cache/$CACHE_NAME"
echo ""

# Verify rosetta builder is configured (on-demand mode)
echo "Checking nix-rosetta-builder configuration..."

# Check if rosetta-builder is in /etc/nix/machines
if [ -f /etc/nix/machines ] && grep -q "rosetta-builder.*aarch64-linux" /etc/nix/machines; then
    echo "✓ Builder configured (on-demand mode - will start when first build is dispatched)"
else
    echo "❌ nix-rosetta-builder not found in /etc/nix/machines"
    echo "   Run 'just activate' in ~/projects/nix-workspace/nix-config"
    exit 1
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Starting nixpkgs-review with cachix watch-exec"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This will:"
echo "  1. Evaluate package changes for aarch64-linux"
echo "  2. Build packages using the rosetta builder (12 cores, 48GB RAM)"
echo "  3. Stream build outputs to cachix as they complete"
echo "  4. Use --keep-going to build as much as possible"
echo ""
echo "Estimated time: 30-90 minutes for 340 packages"
echo ""

# Build package arguments from package list (skip comments and empty lines)
PACKAGE_ARGS=""
if [ -n "$PACKAGE_LIST" ] && [ "$PACKAGE_LIST" != "auto" ]; then
    while IFS= read -r pkg; do
        # Skip comments and empty lines
        [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && continue
        PACKAGE_ARGS="$PACKAGE_ARGS -p $pkg"
    done < "$PACKAGE_LIST"
fi

# Add skip package arguments if specified
SKIP_ARGS=""
if [ -n "$SKIP_PACKAGES" ]; then
    IFS=',' read -ra SKIP_ARRAY <<< "$SKIP_PACKAGES"
    for skip_pkg in "${SKIP_ARRAY[@]}"; do
        SKIP_ARGS="$SKIP_ARGS -P $skip_pkg"
    done
fi

# Run nixpkgs-review with cachix watch-exec to push artifacts as they're built
cd ~/projects/nix-workspace/nix-config && \
sops exec-env secrets/shared.yaml "
    cd ~/projects/nixpkgs && \
    cachix watch-exec \$CACHIX_CACHE_NAME --jobs 12 -- \
        nixpkgs-review rev $BRANCH \
            --branch $BASE_BRANCH \
            --systems aarch64-linux \
            --num-parallel-evals 12 \
            --build-args '--max-jobs 12 --cores 12 --keep-going' \
            $PACKAGE_ARGS \
            $SKIP_ARGS \
            --no-shell
"

EXIT_CODE=$?

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Review complete! All packages built successfully"
else
    echo "⚠️  Review completed with some failures (exit code: $EXIT_CODE)"
    echo "    Check ~/.cache/nixpkgs-review/ for logs"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Build artifacts pushed to: https://app.cachix.org/cache/$CACHE_NAME"
echo "Review results: ~/.cache/nixpkgs-review/rev-$BRANCH/"
echo ""
echo "Next steps:"
echo "  1. Review failures: cat ~/.cache/nixpkgs-review/rev-$BRANCH/report.md"
echo "  2. Test specific package: nix build .#packages.aarch64-linux.PACKAGE"
echo "  3. Re-run for failures: ./scripts/review-linux-with-rosetta.sh $BRANCH $BASE_BRANCH failed-packages.txt"
