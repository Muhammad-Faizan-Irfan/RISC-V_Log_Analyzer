#!/usr/bin/env bash
# generate_report.sh — Runs analyze.sh over all test_data logs and produces
# a combined text summary AND an HTML report in output/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ANALYZE="$SCRIPT_DIR/analyze.sh"
TEST_DATA="$PROJECT_ROOT/test_data"
OUTPUT_DIR="$PROJECT_ROOT/output"

mkdir -p "$OUTPUT_DIR"

HTML_REPORT="$OUTPUT_DIR/report.html"
TEXT_REPORT="$OUTPUT_DIR/summary.txt"

# ─── Collect results from every .log file ────────────────────────────────────
declare -a LOG_FILES=()
while IFS= read -r -d '' f; do
    LOG_FILES+=("$f")
done < <(find "$TEST_DATA" -name "*.log" -print0 | sort -z)

if [[ ${#LOG_FILES[@]} -eq 0 ]]; then
    echo "No .log files found in $TEST_DATA" >&2
    exit 1
fi

# ─── Text summary ─────────────────────────────────────────────────────────────
{
    echo "=== RISC-V Log Analyzer — Batch Summary ==="
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    for log in "${LOG_FILES[@]}"; do
        echo "──────────────────────────────────────────"
        # analyze.sh exits 1 on failures; capture output without aborting this script
        bash "$ANALYZE" "$log" 2>/dev/null || true
        echo ""
    done
} > "$TEXT_REPORT"

echo "Text summary written to: $TEXT_REPORT"

