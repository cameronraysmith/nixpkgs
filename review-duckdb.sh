#!/usr/bin/env bash
set -euo pipefail

# Detect current system architecture for nixpkgs-review
detect_system() {
    local arch
    local os

    arch="$(uname -m)"
    os="$(uname -s)"

    # Normalize architecture name
    case "${arch}" in
        x86_64|amd64)
            arch="x86_64"
            ;;
        aarch64|arm64)
            arch="aarch64"
            ;;
        *)
            echo "Unsupported architecture: ${arch}" >&2
            exit 1
            ;;
    esac

    # Normalize OS name
    case "${os}" in
        Linux)
            os="linux"
            ;;
        Darwin)
            os="darwin"
            ;;
        *)
            echo "Unsupported OS: ${os}" >&2
            exit 1
            ;;
    esac

    echo "${arch}-${os}"
}

main() {
    local system
    local script_dir

    # Get the directory containing this script
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Detect the current system
    system="$(detect_system)"
    echo "Detected system: ${system}" >&2

    # Verify required files exist
    if [[ ! -f "${script_dir}/duckdb-packages-list.txt" ]]; then
        echo "Error: duckdb-packages-list.txt not found in ${script_dir}" >&2
        exit 1
    fi

    if [[ ! -f "${script_dir}/duckdb-packages-failures.txt" ]]; then
        echo "Error: duckdb-packages-failures.txt not found in ${script_dir}" >&2
        exit 1
    fi

    # Build package arguments arrays to avoid shellcheck SC2046
    local -a pkg_args=()
    local -a skip_args=()

    while IFS= read -r pkg; do
        pkg_args+=("-p" "${pkg}")
    done < "${script_dir}/duckdb-packages-list.txt"

    while IFS= read -r pkg; do
        skip_args+=("-P" "${pkg}")
    done < "${script_dir}/duckdb-packages-failures.txt"

    # Run nixpkgs-review with detected system
    nixpkgs-review rev duckdb-132-140 \
        --branch master \
        --systems "${system}" \
        --num-parallel-evals 12 \
        --build-args "--max-jobs 8 --cores 2" \
        "${pkg_args[@]}" \
        "${skip_args[@]}" \
        --print-result \
        --no-shell
}

main "$@"
