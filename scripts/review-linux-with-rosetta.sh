#!/usr/bin/env bash
# Run nixpkgs-review for aarch64-linux using nix-rosetta-builder and push to cachix
set -euo pipefail

BRANCH="${1:-duckdb-132-140}"
BASE_BRANCH="${2:-master}"
PACKAGE_LIST="${3:-duckdb-packages-list.txt}"

if [ ! -f "$PACKAGE_LIST" ]; then
    echo "Error: Package list not found: $PACKAGE_LIST"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "nixpkgs-review for aarch64-linux via nix-rosetta-builder"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Branch: $BRANCH"
echo "Base: $BASE_BRANCH"
echo "Packages: $(wc -l < "$PACKAGE_LIST")"
echo ""

# Get cachix cache name from nix-config
# shellcheck disable=SC2016
CACHE_NAME=$(cd ~/projects/nix-workspace/nix-config && \
    sops exec-env secrets/shared.yaml 'echo $CACHIX_CACHE_NAME')
echo "Cache: https://app.cachix.org/cache/$CACHE_NAME"
echo ""

# Verify rosetta builder is configured
echo "Checking nix-rosetta-builder status..."
if ! nix show-config | grep -q "linux-builder.*ssh://"; then
    echo "❌ nix-rosetta-builder not configured as a remote builder"
    echo "   Run 'just activate' to rebuild your system with rosetta builder"
    exit 1
fi

# Check if builder is accessible (will start on-demand VM)
echo "Testing builder connectivity (may start VM if not running)..."
if ! nix store ping --store ssh-ng://builder@linux-builder &>/dev/null; then
    echo "⚠️  Builder not responding, attempting to start..."
    # The VM should start automatically due to onDemand = true
    sleep 10
    if ! nix store ping --store ssh-ng://builder@linux-builder &>/dev/null; then
        echo "❌ Cannot connect to builder"
        echo "   Try: sudo launchctl kickstart -k system/org.nixos.linux-builder"
        exit 1
    fi
fi

echo "✓ Builder connected and ready"
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
            $(awk '{print "-p", $0}' "$PACKAGE_LIST") \
            --print-result \
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
