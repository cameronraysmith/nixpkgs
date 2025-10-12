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

    # Verify required source files exist
    if [[ ! -f "${script_dir}/duckdb-packages-list.txt" ]]; then
        echo "Error: duckdb-packages-list.txt not found in ${script_dir}" >&2
        exit 1
    fi

    if [[ ! -f "${script_dir}/duckdb-packages-failures.txt" ]]; then
        echo "Error: duckdb-packages-failures.txt not found in ${script_dir}" >&2
        exit 1
    fi

    # Auto-regenerate filtered list if sources are newer or if it doesn't exist
    local filtered_file="${script_dir}/duckdb-packages-filtered.txt"
    local list_file="${script_dir}/duckdb-packages-list.txt"
    local failures_file="${script_dir}/duckdb-packages-failures.txt"

    if [[ ! -f "${filtered_file}" ]] || \
       [[ "${list_file}" -nt "${filtered_file}" ]] || \
       [[ "${failures_file}" -nt "${filtered_file}" ]]; then
        echo "Regenerating ${filtered_file}..." >&2
        comm -23 <(sort "${list_file}") <(sort "${failures_file}") > "${filtered_file}"
        echo "Generated $(wc -l < "${filtered_file}") filtered packages" >&2
    fi

    # Build package arguments array to avoid shellcheck SC2046
    # Note: -P exclusions don't work with -p inclusions due to nixpkgs-review bug
    # (early return bypasses filter_packages), so we use pre-filtered list
    local -a pkg_args=()

    while IFS= read -r pkg; do
        pkg_args+=("-p" "${pkg}")
    done < "${script_dir}/duckdb-packages-filtered.txt"

    # Run nixpkgs-review with detected system
    nixpkgs-review rev duckdb-132-140 \
        --branch master \
        --systems "${system}" \
        --num-parallel-evals 12 \
        --build-args "--max-jobs 8 --cores 2" \
        "${pkg_args[@]}" \
        --print-result \
        --no-shell
}

main "$@"
