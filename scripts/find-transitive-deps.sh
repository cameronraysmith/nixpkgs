#!/usr/bin/env bash
# shellcheck shell=bash
#
# find-transitive-deps.sh - Find all changed packages that transitively depend on a target package
#
# This script uses Nix's fundamental dependency graph operations to determine which packages
# in a nixpkgs-review evaluation transitively depend on a specified package (e.g., sbcl).
#
# Runtime dependencies: bash, coreutils, findutils, git, jq, nix, parallel
#
# Usage:
#   ./scripts/find-transitive-deps.sh [OPTIONS]
#
# Options:
#   --target DEP      Package to find dependencies of (default: sbcl)
#   --branch BRANCH   Branch to review (default: current branch)
#   --base BASE       Base branch to compare against (default: master)
#   --system SYSTEM   Target system (default: aarch64-darwin)
#   --format FORMAT   Output format: list|flags|json (default: flags)
#   --verbose         Show detailed progress
#   --help            Show this help message
#
# Examples:
#   # Find all packages depending on sbcl for current branch
#   ./scripts/find-transitive-deps.sh --target sbcl
#
#   # Find packages depending on llvm for a specific branch
#   ./scripts/find-transitive-deps.sh --target llvm --branch my-feature --base master
#
#   # Get JSON output for further processing
#   ./scripts/find-transitive-deps.sh --target sbcl --format json
#
# Output formats:
#   list  - One attribute path per line
#   flags - Space-separated -P flags for nixpkgs-review
#   json  - JSON array of objects with dependency chains

set -euo pipefail

# Trap handler for graceful exit on Ctrl+C
trap 'echo "" >&2; error "Interrupted by user"; exit 130' INT TERM

# Default configuration
TARGET_DEP="sbcl"
SYSTEM="aarch64-darwin"
BRANCH=""
BASE="master"
FORMAT="flags"
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --target)
      TARGET_DEP="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --base)
      BASE="$2"
      shift 2
      ;;
    --system)
      SYSTEM="$2"
      shift 2
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      grep '^#' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run with --help for usage information"
      exit 1
      ;;
  esac
done

# Utility functions
log() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${BLUE}[INFO]${NC} $*" >&2
  fi
}

error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

# Check for required dependencies
check_dependencies() {
  local missing=()
  local required_deps=(git jq nix-instantiate nix-store timeout)

  for dep in "${required_deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing+=("$dep")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing required dependencies: ${missing[*]}"
    error "Please ensure all required tools are installed"
    exit 1
  fi

  # Check for GNU parallel (optional but recommended for performance)
  if command -v parallel &>/dev/null; then
    # Check if it's GNU parallel (not moreutils parallel)
    if parallel --version 2>&1 | grep -q "GNU parallel"; then
      USE_PARALLEL=true
      log "GNU parallel detected - will use parallel execution"
    else
      USE_PARALLEL=false
      warn "Found 'parallel' but it's not GNU parallel (possibly moreutils)"
      warn "Will use sequential execution (slower)"
      warn "Install GNU parallel for better performance: nix-shell -p parallel"
    fi
  else
    USE_PARALLEL=false
    log "GNU parallel not found - will use sequential execution"
    log "Install for better performance: nix-shell -p parallel"
  fi
}

# Check all required dependencies are available
check_dependencies

# Determine branch
if [[ -z "$BRANCH" ]]; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  log "Using current branch: $BRANCH"
fi

# Get commit hash for cache directory naming
BRANCH_HASH=$(git rev-parse "$BRANCH")

# nixpkgs-review uses the full commit hash plus a counter suffix
# Find the most recent matching directory
REVIEW_DIR=""
for dir in "$HOME/.cache/nixpkgs-review/rev-${BRANCH_HASH}"*; do
  if [[ -d "$dir" ]] && [[ -f "$dir/attrs.nix" ]]; then
    REVIEW_DIR="$dir"
    break
  fi
done

# If not found, try without suffix
if [[ -z "$REVIEW_DIR" ]] || [[ ! -f "$REVIEW_DIR/attrs.nix" ]]; then
  # Look for any directory starting with this commit hash
  REVIEW_DIR=$(find "$HOME/.cache/nixpkgs-review" -maxdepth 1 -type d -name "rev-${BRANCH_HASH}*" 2>/dev/null | sort -r | head -1)
fi

log "Configuration:"
log "  Target dependency: $TARGET_DEP"
log "  Branch: $BRANCH ($BRANCH_HASH)"
log "  Base: $BASE"
log "  System: $SYSTEM"
log "  Format: $FORMAT"
log "  Review directory: $REVIEW_DIR"

# Check if we found a valid cache directory
if [[ -z "$REVIEW_DIR" ]] || [[ ! -f "$REVIEW_DIR/attrs.nix" ]]; then
  warn "No cached evaluation found for commit $BRANCH_HASH"
  warn "You need to run nixpkgs-review first to generate the evaluation:"
  warn "  nixpkgs-review rev $BRANCH --branch $BASE --systems $SYSTEM"
  warn ""
  warn "Alternatively, interrupt the build early (Ctrl-C) after seeing 'X packages updated'"
  exit 1
fi

success "Found cached evaluation at $REVIEW_DIR/attrs.nix"

# Extract changed attribute paths from nixpkgs-review's evaluation
log "Extracting changed packages from nixpkgs-review evaluation..."

# attrs.nix is an attribute set keyed by system: { aarch64-darwin = [ ... ]; aarch64-linux = [ ... ]; }
# Check what systems are available
AVAILABLE_SYSTEMS=$(nix-instantiate --eval --strict --json "$REVIEW_DIR/attrs.nix" 2>/dev/null | jq -r 'keys[]')

if [[ -z "$AVAILABLE_SYSTEMS" ]]; then
  error "Failed to parse attrs.nix"
  exit 1
fi

log "Available systems in evaluation: $(echo "$AVAILABLE_SYSTEMS" | tr '\n' ' ')"

# Try to use the requested system, fall back to any available system if not found
EVAL_SYSTEM="$SYSTEM"
if ! echo "$AVAILABLE_SYSTEMS" | grep -q "^${SYSTEM}$"; then
  EVAL_SYSTEM=$(echo "$AVAILABLE_SYSTEMS" | head -1)
  warn "Requested system '$SYSTEM' not found in evaluation"
  warn "Using '$EVAL_SYSTEM' instead (dependency closure is usually similar)"
fi

# Extract the array for the chosen system
CHANGED_ATTRS=$(nix-instantiate --eval --strict --json "$REVIEW_DIR/attrs.nix" 2>/dev/null | \
  jq -r --arg system "$EVAL_SYSTEM" '.[$system] | .[]' 2>/dev/null) || {
  error "Failed to extract packages for system: $EVAL_SYSTEM"
  exit 1
}

if [[ -z "$CHANGED_ATTRS" ]]; then
  error "No packages found for system: $EVAL_SYSTEM"
  exit 1
fi

TOTAL_CHANGED=$(echo "$CHANGED_ATTRS" | wc -l | tr -d ' ')
log "Found $TOTAL_CHANGED changed packages (evaluated for: $EVAL_SYSTEM, querying for: $SYSTEM)"

# Verify the target package can be instantiated
log "Resolving target package: $TARGET_DEP"
if ! nix-instantiate --argstr system "$SYSTEM" -A "$TARGET_DEP" 2>/dev/null >/dev/null; then
  error "Cannot instantiate target package: $TARGET_DEP"
  error "Make sure the package exists and is buildable for $SYSTEM"
  exit 1
fi

# Calculate number of parallel jobs (ncpus - 1, minimum 1)
if [[ "$USE_PARALLEL" == "true" ]]; then
  NCPUS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
  NJOBS=$((NCPUS - 1))
  if [[ $NJOBS -lt 1 ]]; then
    NJOBS=1
  fi
  log "Using $NJOBS parallel jobs (detected $NCPUS CPUs)"
fi

# Function to check a single package (will be called in parallel)
check_package_dependency() {
  local attr="$1"
  local system="$2"
  local target_dep="$3"
  local verbose="$4"

  # Skip output-specific attributes (like .dist, .doc, .man)
  if [[ "$attr" =~ \.(dist|doc|man|dev|lib|bin|out)$ ]]; then
    if [[ "$verbose" == "true" ]]; then
      echo "SKIP:$attr" >&2
    fi
    return 0
  fi

  # Instantiate the derivation (with 10s timeout)
  local drv
  drv=$(timeout 10 nix-instantiate --argstr system "$system" -A "$attr" 2>/dev/null) || {
    if [[ "$verbose" == "true" ]]; then
      echo "FAIL_INST:$attr" >&2
    fi
    return 0
  }

  # Query the full build-time dependency closure (with 10s timeout)
  local deps
  deps=$(timeout 10 nix-store --query --requisites --include-outputs "$drv" 2>/dev/null) || {
    if [[ "$verbose" == "true" ]]; then
      echo "FAIL_QUERY:$attr" >&2
    fi
    return 0
  }

  # Check if target appears in the closure
  if echo "$deps" | grep -q "$target_dep"; then
    echo "DEPENDS:$attr"
    return 0
  else
    if [[ "$verbose" == "true" ]]; then
      echo "NO_DEP:$attr" >&2
    fi
    return 0
  fi
}

# Export function and variables for parallel
export -f check_package_dependency
export SYSTEM TARGET_DEP VERBOSE

# Analyze each changed package in parallel
log "Analyzing dependency closures..."
log "Press Ctrl+C to interrupt at any time"

# Run analysis (parallel or sequential based on availability)
DEPENDS_ON_TARGET=()

if [[ "$USE_PARALLEL" == "true" ]]; then
  # Parallel execution with GNU parallel
  while IFS= read -r line; do
    if [[ "$line" == DEPENDS:* ]]; then
      pkg="${line#DEPENDS:}"
      DEPENDS_ON_TARGET+=("$pkg")
      if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${GREEN}✓${NC} $pkg depends on $TARGET_DEP" >&2
      fi
    elif [[ "$VERBOSE" == "true" ]]; then
      case "$line" in
        SKIP:*)
          pkg="${line#SKIP:}"
          echo -e "${BLUE}⊙${NC} Skipping output: $pkg" >&2
          ;;
        FAIL_INST:*)
          pkg="${line#FAIL_INST:}"
          echo -e "${YELLOW}⊘${NC} Cannot instantiate: $pkg" >&2
          ;;
        FAIL_QUERY:*)
          pkg="${line#FAIL_QUERY:}"
          echo -e "${YELLOW}⊘${NC} Cannot query dependencies: $pkg" >&2
          ;;
        NO_DEP:*)
          pkg="${line#NO_DEP:}"
          echo -e "○ No dependency: $pkg" >&2
          ;;
      esac
    fi
  done < <(echo "$CHANGED_ATTRS" | parallel --line-buffer --jobs "$NJOBS" check_package_dependency {} "$SYSTEM" "$TARGET_DEP" "$VERBOSE")
else
  # Sequential execution fallback
  CURRENT=0
  while IFS= read -r attr; do
    CURRENT=$((CURRENT + 1))
    if [[ "$VERBOSE" == "true" ]]; then
      echo -e "${BLUE}[$CURRENT/$TOTAL_CHANGED]${NC} Checking: $attr" >&2
    fi

    # Skip output-specific attributes
    if [[ "$attr" =~ \.(dist|doc|man|dev|lib|bin|out)$ ]]; then
      log "  ⊙ Skipping output: $attr"
      continue
    fi

    # Instantiate the derivation
    drv=$(timeout 10 nix-instantiate --argstr system "$SYSTEM" -A "$attr" 2>/dev/null) || {
      log "  ⊘ Cannot instantiate: $attr"
      continue
    }

    # Query dependencies
    deps=$(timeout 10 nix-store --query --requisites --include-outputs "$drv" 2>/dev/null) || {
      log "  ⊘ Cannot query dependencies: $attr"
      continue
    }

    # Check if target appears in closure
    if echo "$deps" | grep -q "$TARGET_DEP"; then
      log "  ${GREEN}✓${NC} DEPENDS on $TARGET_DEP"
      DEPENDS_ON_TARGET+=("$attr")
    else
      log "  ○ No dependency"
    fi
  done <<< "$CHANGED_ATTRS"
fi

# Output results based on format
case "$FORMAT" in
  list)
    # One attribute per line
    printf '%s\n' "${DEPENDS_ON_TARGET[@]}"
    ;;

  flags)
    # Space-separated -P flags for nixpkgs-review
    if [[ ${#DEPENDS_ON_TARGET[@]} -gt 0 ]]; then
      printf -- '-P %s ' "${DEPENDS_ON_TARGET[@]}"
      echo ""
    fi
    ;;

  json)
    # JSON array with optional dependency chains
    echo "["
    for i in "${!DEPENDS_ON_TARGET[@]}"; do
      echo -n "  {\"package\": \"${DEPENDS_ON_TARGET[$i]}\""
      if [[ ${#DEPENDENCY_CHAINS[@]} -gt $i ]]; then
        echo -n ", \"chain\": \"${DEPENDENCY_CHAINS[$i]}\""
      fi
      echo -n "}"
      if [[ $i -lt $((${#DEPENDS_ON_TARGET[@]} - 1)) ]]; then
        echo ","
      else
        echo ""
      fi
    done
    echo "]"
    ;;

  *)
    error "Unknown format: $FORMAT"
    exit 1
    ;;
esac

# Summary to stderr
echo "" >&2
success "Analysis complete" >&2
echo -e "${BLUE}Summary:${NC}" >&2
echo "  Changed packages analyzed: $TOTAL_CHANGED" >&2
echo "  Packages depending on $TARGET_DEP: ${#DEPENDS_ON_TARGET[@]}" >&2

if [[ ${#DEPENDS_ON_TARGET[@]} -gt 0 ]]; then
  echo "" >&2
  echo -e "${YELLOW}To exclude these from nixpkgs-review, add these flags:${NC}" >&2
  echo -e "${GREEN}$(printf -- '-P %s ' "${DEPENDS_ON_TARGET[@]}")${NC}" >&2
fi
