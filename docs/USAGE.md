# USAGE — riscv-log-analyzer

Detailed command reference for `scripts/analyze.sh` and the supporting scripts.

---

## analyze.sh

```
bash scripts/analyze.sh <log-file> [OPTIONS]
```

### Positional argument

| Argument    | Required | Description                       |
|-------------|----------|-----------------------------------|
| `<log-file>`| Yes      | Path to the `.log` file to parse  |

### Options

| Flag                    | Default | Description                                           |
|-------------------------|---------|-------------------------------------------------------|
| `--format [text\|csv]`  | `text`  | Output format                                         |
| `--output <path>`       | stdout  | Write report to this file instead of printing         |
| `--compare <log-file>`  | —       | Diff two runs; show regressions and improvements      |
| `--verbose`             | off     | Print per-test debug lines to stderr                  |
| `--help`                | —       | Print usage and exit                                  |

### Exit codes

- **0** — all tests passed (or no tests found)
- **1** — at least one test failed

---

## Text output format

```
=== RISC-V Simulation Log Analysis ===
Log file:      <path>
Analysis date: YYYY-MM-DD HH:MM:SS

--- Results Summary ---
Total tests:   N
Passed:        N (X%)
Failed:        N (X%)
Skipped:       N (X%)

--- Failed Tests ---           # only shown if FAILED > 0
  1. <test-name>
  2. <test-name>

--- Timing Statistics ---      # only shown when timing data present
Min time:  Xs  (<test-name>)
Max time:  Xs  (<test-name>)
Avg time:  Xs

--- Verdict: PASS|FAIL ---
```

When writing to a terminal, PASS lines are green and FAIL lines are red (ANSI
color codes). Color is suppressed when output is redirected to a file.

---

## CSV output format

```
metric,value
log_file,<path>
analysis_date,YYYY-MM-DD HH:MM:SS
total,N
passed,N
failed,N
skipped,N
pass_rate_pct,X.X
min_time_s,X.XX
min_time_test,<name>
max_time_s,X.XX
max_time_test,<name>
avg_time_s,X.XX

result,test_name,time_s
PASS,rv32i-add,0.82
FAIL,rv32i-sll,1.02
…
```

---

## --compare (regression detection)

```bash
bash scripts/analyze.sh new_run.log --compare old_run.log
```

Appended section after the normal text report:

```
=== Regression Comparison ===
Baseline:  old_run.log
Current:   new_run.log

Regressions (passed before, fail now):
  ✗ rv32i-sll
  ✗ rv32i-beq

Improvements (failed before, pass now):
  ✓ rv32i-sub
```

---

## generate_report.sh

Processes all `*.log` files in `test_data/` and writes:

- `output/summary.txt` — concatenated text reports
- `output/report.html` — styled HTML table with per-file sections

```bash
bash scripts/generate_report.sh
# or
make report
```

---

## setup_env.sh

Checks that `bash`, `grep`, `awk`, `sed`, `date`, and `mkdir` are available,
then creates the `output/` directory.

```bash
bash scripts/setup_env.sh
# or
make setup
```

---

## Expected log format

```
[YYYY-MM-DD HH:MM:SS] TEST START: <name>
[YYYY-MM-DD HH:MM:SS] TEST PASS:  <name> (<time>s)
[YYYY-MM-DD HH:MM:SS] TEST FAIL:  <name> (<time>s)
[YYYY-MM-DD HH:MM:SS] ERROR: <message>
[YYYY-MM-DD HH:MM:SS] TEST SKIP:  <name> (<reason>)
[YYYY-MM-DD HH:MM:SS] SUMMARY: N tests, N passed, N failed, N skipped
```

Timing `(<Xs>)` is optional; missing timing simply omits the statistics section.
