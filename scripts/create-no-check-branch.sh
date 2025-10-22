#!/usr/bin/env bash
# Create a temporary branch with checks disabled
set -euo pipefail

SOURCE_BRANCH="${1:-duckdb-132-140}"
TARGET_BRANCH="${SOURCE_BRANCH}-no-checks"

echo "Creating no-checks branch: $TARGET_BRANCH from $SOURCE_BRANCH"

# Create new branch
git checkout -b "$TARGET_BRANCH" "$SOURCE_BRANCH"

# Add overlay to disable checks
cat > pkgs/top-level/disable-checks-overlay.nix <<'EOF'
# Temporary overlay to disable all checks for faster caching
self: super: {
  stdenv = super.stdenv.override (old: {
    mkDerivation = args: super.stdenv.mkDerivation (args // {
      doCheck = false;
      doInstallCheck = false;
    });
  });
}
EOF

# Apply the overlay in all-packages.nix or pkgs/top-level/default.nix
# This would require manually editing the file structure

echo "WARNING: This approach requires manually integrating the overlay"
echo "Overlay created at: pkgs/top-level/disable-checks-overlay.nix"
echo
echo "To use it, you'd need to modify pkgs/top-level/impure.nix or similar"
echo "This is complex and not recommended for nixpkgs-review workflow"
echo
echo "Better approach: Use batching + --keep-going + --skip-package"

git checkout "$SOURCE_BRANCH"
git branch -D "$TARGET_BRANCH" 2>/dev/null || true
rm -f pkgs/top-level/disable-checks-overlay.nix
