#!/usr/bin/env bash
# setup_env.sh — Verify that all required tools are present and output/ exists.

set -euo pipefail

REQUIRED_TOOLS=(bash grep awk sed date mkdir)

echo "=== RISC-V Log Analyzer — Environment Setup ==="
echo ""

ALL_OK=true

for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        printf "  %-10s  %s\n" "$tool" "✓  $(command -v "$tool")"
    else
        printf "  %-10s  ✗  NOT FOUND\n" "$tool"
        ALL_OK=false
    fi
done

echo ""

# Create output directory if it doesn't exist
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/output"

if [[ ! -d "$OUTPUT_DIR" ]]; then
    mkdir -p "$OUTPUT_DIR"
    echo "Created output directory: $OUTPUT_DIR"
else
    echo "Output directory already exists: $OUTPUT_DIR"
fi

echo ""

if $ALL_OK; then
    echo "✓ Environment is ready."
    exit 0
else
    echo "✗ One or more required tools are missing. Please install them and re-run."
    exit 1
fi
