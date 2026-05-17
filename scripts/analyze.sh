#!/usr/bin/env bash
# analyze.sh — Simple RISC-V simulation log analyzer

set -euo pipefail

# ─── Colors (global) ──────────────────────────────────────────────────────────
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
    if [[ $# -eq 0 ]]; then
        echo "Error: please provide a log file." >&2
        usage >&2
        exit 1
    fi

    LOG_FILE="$1"
    shift

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

# ─── Count results ────────────────────────────────────────────────────────────
parse_log() {
    PASSED=$(grep -c  "TEST PASS:"  "$LOG_FILE" || true)
    FAILED=$(grep -c  "TEST FAIL:"  "$LOG_FILE" || true)
    SKIPPED=$(grep -c "TEST SKIP:"  "$LOG_FILE" || true)
    TOTAL=$(( PASSED + FAILED + SKIPPED ))

    FAIL_NAMES=$(grep "TEST FAIL:" "$LOG_FILE" | awk '{print $5}' || true)
    PASS_NAMES=$(grep "TEST PASS:" "$LOG_FILE" | awk '{print $5}' || true)

    if $VERBOSE; then
        grep "TEST PASS:\|TEST FAIL:\|TEST SKIP:" "$LOG_FILE" | while read -r line; do
            echo "[verbose] $line" >&2
        done
    fi

    NAME_TIMES=$(grep -E "TEST (PASS|FAIL):" "$LOG_FILE" \
        | awk '{
            name = $5
            time = $6
            gsub(/[()s]/, "", time)
            print time, name
          }' \
        || true)
}

# ─── Compute timing stats ─────────────────────────────────────────────────────
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
            t = $1
            n = $2
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
    local pass_pct=0 fail_pct=0 skip_pct=0
    if [[ $TOTAL -gt 0 ]]; then
        pass_pct=$(awk "BEGIN{ printf \"%.1f\", ($PASSED/$TOTAL)*100 }")
        fail_pct=$(awk "BEGIN{ printf \"%.1f\", ($FAILED/$TOTAL)*100 }")
        skip_pct=$(awk "BEGIN{ printf \"%.1f\", ($SKIPPED/$TOTAL)*100 }")
    fi

    # ── Copy global colors into LOCAL variables ───────────────────────────────
    local c_red="$RED"
    local c_green="$GREEN"
    local c_yellow="$YELLOW"
    local c_cyan="$CYAN"
    local c_bold="$BOLD"
    local c_reset="$RESET"

    # -t 1 checks if stdout is a terminal
    # if output is going to a file or pipe → disable colors
    if [[ ! -t 1 ]]; then
        c_red=""; c_green=""; c_yellow=""
        c_cyan=""; c_bold=""; c_reset=""
    fi

    # ── Now use c_* local variables everywhere ─────────────
    echo -e "${c_cyan}${c_bold}=== RISC-V Simulation Log Analysis ===${c_reset}"
    echo    "Log file:      $LOG_FILE"
    echo    "Analysis date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo    ""
    echo -e "${c_bold}--- Results Summary ---${c_reset}"
    printf  "Total tests:   %d\n"                          "$TOTAL"
    printf  "${c_green}Passed:        %d (%s%%)${c_reset}\n"  "$PASSED"  "$pass_pct"
    printf  "${c_red}Failed:        %d (%s%%)${c_reset}\n"    "$FAILED"  "$fail_pct"
    printf  "${c_yellow}Skipped:       %d (%s%%)${c_reset}\n" "$SKIPPED" "$skip_pct"

    if [[ -n "$FAIL_NAMES" ]]; then
        echo ""
        echo -e "${c_bold}--- Failed Tests ---${c_reset}"
        local i=1
        while IFS= read -r name; do
            printf "${c_red}  %d. %s${c_reset}\n" "$i" "$name"
            (( i++ )) || true
        done <<< "$FAIL_NAMES"
    fi

    if [[ -n "$MIN_TIME" ]]; then
        echo ""
        echo -e "${c_bold}--- Timing Statistics ---${c_reset}"
        printf "Min time:      %ss  (%s)\n" "$MIN_TIME" "$MIN_TEST"
        printf "Max time:      %ss  (%s)\n" "$MAX_TIME" "$MAX_TEST"
        printf "Avg time:      %ss\n"        "$AVG_TIME"
    fi

    echo ""
    if [[ $FAILED -eq 0 ]]; then
        echo -e "${c_green}${c_bold}--- Verdict: PASS ---${c_reset}"
    else
        echo -e "${c_red}${c_bold}--- Verdict: FAIL ---${c_reset}"
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
    while IFS= read -r name; do
        [[ -n "$name" ]] && echo "PASS,$name"
    done <<< "$PASS_NAMES"
    while IFS= read -r name; do
        [[ -n "$name" ]] && echo "FAIL,$name"
    done <<< "$FAIL_NAMES"
}

# ─── Compare two logs ─────────────────────────────────────────────────────────
compare_logs() {
    echo -e "${BOLD}=== Regression Comparison ===${RESET}"
    echo "Baseline : $COMPARE_FILE"
    echo "Current  : $LOG_FILE"
    echo ""

    local old_passes
    old_passes=$(grep "TEST PASS:" "$COMPARE_FILE" | awk '{print $5}' || true)

    local old_fails
    old_fails=$(grep "TEST FAIL:" "$COMPARE_FILE" | awk '{print $5}' || true)

    local found_regression=false
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        if echo "$old_passes" | grep -qx "$name"; then
            if ! $found_regression; then
                echo -e "${RED}Regressions (passed before, fail now):${RESET}"
                found_regression=true
            fi
            echo -e "  ${RED}✗ $name${RESET}"
        fi
    done <<< "$FAIL_NAMES"

    $found_regression || echo -e "${GREEN}No regressions detected.${RESET}"

    local found_improvement=false
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        if echo "$old_fails" | grep -qx "$name"; then
            if ! $found_improvement; then
                echo ""
                echo -e "${GREEN}Improvements (failed before, pass now):${RESET}"
                found_improvement=true
            fi
            echo -e "  ${GREEN}✓ $name${RESET}"
        fi
    done <<< "$PASS_NAMES"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"
    validate_inputs
    parse_log
    compute_timing_stats

    if [[ -n "$OUTPUT" ]]; then
        # saving to file → redirect whole block, -t 1 sees "not a terminal" → no colors
        mkdir -p "$(dirname "$OUTPUT")"
        {
            if [[ "$FORMAT" == "csv" ]]; then
                output_csv
            else
                output_text
            fi
            if [[ -n "$COMPARE_FILE" && "$FORMAT" == "text" ]]; then
                compare_logs
            fi
        } > "$OUTPUT"
        echo "Report saved to: $OUTPUT" >&2
    else
        # printing to terminal → functions run directly → -t 1 sees real terminal → colors ON
        if [[ "$FORMAT" == "csv" ]]; then
            output_csv
        else
            output_text
        fi
        if [[ -n "$COMPARE_FILE" && "$FORMAT" == "text" ]]; then
            compare_logs
        fi
    fi

    [[ $FAILED -gt 0 ]] && exit 1
    exit 0
}

main "$@"
