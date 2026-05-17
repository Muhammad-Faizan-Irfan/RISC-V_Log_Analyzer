#!/usr/bin/env bash
# analyze.sh — Simple RISC-V simulation log analyzer
# Uses grep and pipes instead of regex/BASH_REMATCH — easier to read!

set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Defaults ─────────────────────────────────────────────────────────────────
FORMAT="text"
OUTPUT=""
VERBOSE=false
COMPARE_FILE=""
LOG_FILE=""

# ─── Help message ─────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") <log-file> [OPTIONS]

Options:
  --format [text|csv]   Output format (default: text)
  --output <path>       Save report to a file instead of printing
  --compare <log-file>  Compare two logs and show regressions
  --verbose             Show each test as it is counted
  --help                Show this message

Exit codes:
  0  All tests passed
  1  One or more tests failed

Examples:
  $(basename "$0") test_data/sample_fail.log
  $(basename "$0") test_data/sample_pass.log --format csv
  $(basename "$0") new.log --compare old.log
EOF
}

# ─── Read arguments ───────────────────────────────────────────────────────────
parse_args() {
    # Need at least one argument
    if [[ $# -eq 0 ]]; then
        echo "Error: please provide a log file." >&2
        usage >&2
        exit 1
    fi

    LOG_FILE="$1"   # first argument is always the log file
    shift           # remove it so we can loop over the rest

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --format)
                FORMAT="$2"
                shift 2
                ;;
            --output)
                OUTPUT="$2"
                shift 2
                ;;
            --compare)
                COMPARE_FILE="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                echo "Error: unknown option '$1'" >&2
                exit 1
                ;;
        esac
    done
}

