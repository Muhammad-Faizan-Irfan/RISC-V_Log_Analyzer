# riscv-log-analyzer

A shell-based tool that processes **RISC-V simulation log files**, extracts test
results and timing data, and generates readable summary reports.

---

## Features

- Parses `PASS`, `FAIL`, and `SKIP` results from structured simulation logs
- Reports pass rate, timing statistics (min/max/avg), and the full list of failures
- Outputs in **plain text** (with optional ANSI color) or **CSV**
- Generates a combined **HTML report** across all log files
- Bonus `--compare` flag for regression detection between two runs

---

## Installation

```bash
git clone https://github.com/your-username/riscv-log-analyzer.git
cd riscv-log-analyzer
make setup        # verify required tools (bash, grep, awk, …)
chmod +x scripts/*.sh
```

No external dependencies beyond standard POSIX tools.

---

## Usage

```bash
# Analyze a single log (text output to stdout)
bash scripts/analyze.sh test_data/sample_fail.log

# Save as CSV
bash scripts/analyze.sh test_data/sample_fail.log --format csv --output output/results.csv

# Verbose mode
bash scripts/analyze.sh test_data/sample_sim.log --verbose

# Compare two runs (regression detection)
bash scripts/analyze.sh test_data/sample_fail.log \
     --compare test_data/sample_pass.log

# Help
bash scripts/analyze.sh --help
```

### Makefile shortcuts

| Target        | Description                                      |
|---------------|--------------------------------------------------|
| `make all`    | Analyze every log file in `test_data/`           |
| `make test`   | Save per-file reports to `output/`               |
| `make report` | Generate combined text + HTML report             |
| `make clean`  | Delete everything in `output/`                   |
| `make setup`  | Check required tools are installed               |
| `make help`   | Print this table                                 |

---

## Sample Output

```
=== RISC-V Simulation Log Analysis ===
Log file:      test_data/sample_fail.log
Analysis date: 2026-05-05 14:30:00

--- Results Summary ---
Total tests:   25
Passed:        22 (88.0%)
Failed:        2 (8.0%)
Skipped:       1 (4.0%)

--- Failed Tests ---
  1. rv32i-sll
  2. rv32i-beq

--- Timing Statistics ---
Min time:      0.42s  (rv32i-nop)
Max time:      2.31s  (rv32i-mul)
Avg time:      0.87s

--- Verdict: FAIL ---
```

---

## Log Format

```
[2026-05-01 10:23:45] TEST START: rv32i-add
[2026-05-01 10:23:46] TEST PASS:  rv32i-add (0.82s)
[2026-05-01 10:23:47] TEST FAIL:  rv32i-sll (1.02s)
[2026-05-01 10:23:48] ERROR: Signature mismatch at line 42
[2026-05-01 10:23:48] TEST SKIP:  rv32i-srl (not supported)
[2026-05-01 10:30:12] SUMMARY: 25 tests, 22 passed, 2 failed, 1 skipped
```

---

## Exit Codes

| Code | Meaning                    |
|------|----------------------------|
| `0`  | All tests passed           |
| `1`  | One or more tests failed   |

---

## Project Structure

```
riscv-log-analyzer/
├── README.md               # Project description, usage, examples
├── Makefile                # Build & run automation
├── .gitignore              # Proper ignore rules
├── scripts/
│   ├── analyze.sh          # Main analysis script
│   ├── setup_env.sh        # Tool verification
│   └── generate_report.sh  # Batch HTML + text report
├── test_data/
│   ├── sample_sim.log      # Mixed results
│   ├── sample_pass.log     # All passing
│   └── sample_fail.log     # Multiple failures
├── output/                 # Generated (gitignored)
└── docs/
    └── USAGE.md            # Detailed usage guide

```


