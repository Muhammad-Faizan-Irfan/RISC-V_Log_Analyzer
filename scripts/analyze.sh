#!/usr/bin/env bash
# analyze.sh — Simple RISC-V simulation log analyzer

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

# ─── Check the log file exists ────────────────────────────────────────────────
validate_inputs() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "Error: file not found: $LOG_FILE" >&2
        exit 1
    fi
}

# ─── Count results  ───────────────────────────────────────────────────────────
parse_log() {
    # Count how many lines contain each keyword
    # grep returns exit code 1 if no match found, so we add || true to be safe
    PASSED=$(grep -c  "TEST PASS:"  "$LOG_FILE" || true)
    FAILED=$(grep -c  "TEST FAIL:"  "$LOG_FILE" || true)
    SKIPPED=$(grep -c "TEST SKIP:"  "$LOG_FILE" || true)
    TOTAL=$(( PASSED + FAILED + SKIPPED ))
    FAIL_NAMES=$(grep "TEST FAIL:" "$LOG_FILE" | awk '{print $5}' || true)

    # Get the list of passing test names (used by --compare)
    PASS_NAMES=$(grep "TEST PASS:" "$LOG_FILE" | awk '{print $5}' || true)

    # Show each test while counting (only if --verbose)
    if $VERBOSE; then
        grep "TEST PASS:\|TEST FAIL:\|TEST SKIP:" "$LOG_FILE" | while read -r line; do
            echo "[verbose] $line" >&2
        done
    fi

    ALL_TIMES=$(grep -E "TEST (PASS|FAIL):" "$LOG_FILE" \
        | awk '{print $6}' \
        | tr -d '()' \
        | sed 's/s$//' \
        || true)

    NAME_TIMES=$(grep -E "TEST (PASS|FAIL):" "$LOG_FILE" \
        | awk '{
            name = $5
            time = $6
            gsub(/[()s]/, "", time)   # remove ( ) and s from the time
            print time, name
          }' \
        || true)
}

# ─── Compute timing stats ─────────────────────────────────────────────────────
# We use awk to find min/max/avg because bash cannot do decimal math
compute_timing_stats() {
    if [[ -z "$NAME_TIMES" ]]; then
        MIN_TIME=""; MAX_TIME=""; AVG_TIME=""
        MIN_TEST=""; MAX_TEST=""
        return
    fi


    read -r MIN_TIME MIN_TEST MAX_TIME MAX_TEST AVG_TIME <<< "$(
        echo "$NAME_TIMES" | awk '
        BEGIN { min=999999; max=0; sum=0; count=0 }
        {
            t = $1       # time value (e.g. 0.82)
            n = $2       # test name  (e.g. rv32i-add)
            if (t < min) { min = t; min_name = n }
            if (t > max) { max = t; max_name = n }
            sum += t
            count++
        }
        END {
            avg = (count > 0) ? sum/count : 0
            printf "%.2f %s %.2f %s %.2f\n", min, min_name, max, max_name, avg
        }'
    )"
}

# ─── Print the text report ────────────────────────────────────────────────────
output_text() {
    # Calculate percentages using awk (bash can't do decimals)
    local pass_pct=0 fail_pct=0 skip_pct=0
    if [[ $TOTAL -gt 0 ]]; then
        pass_pct=$(awk "BEGIN{ printf \"%.1f\", ($PASSED/$TOTAL)*100 }")
        fail_pct=$(awk "BEGIN{ printf \"%.1f\", ($FAILED/$TOTAL)*100 }")
        skip_pct=$(awk "BEGIN{ printf \"%.1f\", ($SKIPPED/$TOTAL)*100 }")
    fi

    echo -e "${CYAN}${BOLD}=== RISC-V Simulation Log Analysis ===${RESET}"
    echo    "Log file:      $LOG_FILE"
    echo    "Analysis date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo    ""
    echo -e "${BOLD}--- Results Summary ---${RESET}"
    printf  "Total tests:   %d\n"               "$TOTAL"
    printf  "${GREEN}Passed:        %d (%s%%)${RESET}\n"  "$PASSED"  "$pass_pct"
    printf  "${RED}Failed:        %d (%s%%)${RESET}\n"    "$FAILED"  "$fail_pct"
    printf  "${YELLOW}Skipped:       %d (%s%%)${RESET}\n" "$SKIPPED" "$skip_pct"

    # Print failing test names (if any)
    if [[ -n "$FAIL_NAMES" ]]; then
        echo ""
        echo -e "${BOLD}--- Failed Tests ---${RESET}"
        local i=1
        # Loop over each name (one per line thanks to grep output)
        while IFS= read -r name; do
            printf "${RED}  %d. %s${RESET}\n" "$i" "$name"
            (( i++ )) || true
        done <<< "$FAIL_NAMES"
    fi

    # Print timing stats (if we got any times from the log)
    if [[ -n "$MIN_TIME" ]]; then
        echo ""
        echo -e "${BOLD}--- Timing Statistics ---${RESET}"
        printf "Min time:      %ss  (%s)\n" "$MIN_TIME" "$MIN_TEST"
        printf "Max time:      %ss  (%s)\n" "$MAX_TIME" "$MAX_TEST"
        printf "Avg time:      %ss\n"        "$AVG_TIME"
    fi

    echo ""
    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}--- Verdict: PASS ---${RESET}"
    else
        echo -e "${RED}${BOLD}--- Verdict: FAIL ---${RESET}"
    fi
}

# ─── Print the CSV report ─────────────────────────────────────────────────────
output_csv() {
    local pass_pct=0
    [[ $TOTAL -gt 0 ]] && pass_pct=$(awk "BEGIN{ printf \"%.1f\", ($PASSED/$TOTAL)*100 }")

    echo "metric,value"
    echo "log_file,$LOG_FILE"
    echo "analysis_date,$(date '+%Y-%m-%d %H:%M:%S')"
    echo "total,$TOTAL"
    echo "passed,$PASSED"
    echo "failed,$FAILED"
    echo "skipped,$SKIPPED"
    echo "pass_rate_pct,$pass_pct"

    if [[ -n "$MIN_TIME" ]]; then
        echo "min_time_s,$MIN_TIME"
        echo "min_time_test,$MIN_TEST"
        echo "max_time_s,$MAX_TIME"
        echo "max_time_test,$MAX_TEST"
        echo "avg_time_s,$AVG_TIME"
    fi

    echo ""
    echo "result,test_name"
    # Print each passing test name with PASS label
    while IFS= read -r name; do
        [[ -n "$name" ]] && echo "PASS,$name"
    done <<< "$PASS_NAMES"
    # Print each failing test name with FAIL label
    while IFS= read -r name; do
        [[ -n "$name" ]] && echo "FAIL,$name"
    done <<< "$FAIL_NAMES"
}


