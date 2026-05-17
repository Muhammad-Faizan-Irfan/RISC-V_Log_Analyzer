# Makefile — riscv-log-analyzer
# Automates analysis, testing, report generation, and cleanup.

SHELL       := /bin/bash
ANALYZE     := scripts/analyze.sh
GEN_REPORT  := scripts/generate_report.sh
SETUP       := scripts/setup_env.sh
TEST_DATA   := test_data
OUTPUT_DIR  := output

# Collect all log files in test_data/
LOG_FILES   := $(wildcard $(TEST_DATA)/*.log)

# Default target — analyze all log files
.PHONY: all
all: $(OUTPUT_DIR)
	@echo "=== Analyzing all log files ==="
	@for log in $(LOG_FILES); do \
	    echo ""; \
	    echo "--- $$log ---"; \
	    bash $(ANALYZE) "$$log" || true; \
	done

# Run analyzer on each test file
.PHONY: test
test: $(OUTPUT_DIR)
	@echo "=== Running test suite ==="
	@PASS=0; FAIL=0; \
	for log in $(LOG_FILES); do \
	    name=$$(basename "$$log" .log); \
	    out="$(OUTPUT_DIR)/$$name.txt"; \
	    bash $(ANALYZE) "$$log" --output "$$out" 2>/dev/null || true; \
	    if [[ -f "$$out" ]]; then \
	        echo "  ✓  $$log  →  $$out"; \
	        PASS=$$((PASS+1)); \
	    else \
	        echo "  ✗  $$log  — output not created"; \
	        FAIL=$$((FAIL+1)); \
	    fi; \
	done; \
	echo ""; \
	echo "Results: $$PASS passed, $$FAIL failed."

# Generate summary text + HTML report
.PHONY: report
report: $(OUTPUT_DIR)
	@echo "=== Generating report ==="
	@bash $(GEN_REPORT)

