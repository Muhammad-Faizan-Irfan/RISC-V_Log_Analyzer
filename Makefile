# Makefile — riscv-log-analyzer

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
	

# Remove all generated output
.PHONY: clean
clean:
	@echo "Cleaning output directory..."
	@rm -rf $(OUTPUT_DIR)
	@echo "Done."

# Print all available targets with descriptions
.PHONY: help
help:
	@echo ""
	@echo "riscv-log-analyzer — Makefile targets"
	@echo "======================================"
	@echo "  make all      Analyze every .log file in test_data/ (stdout)"
	@echo "  make test     Run analyzer on each test file; save to output/"
	@echo "  make report   Generate combined text + HTML report in output/"
	@echo "  make clean    Remove all generated files in output/"
	@echo "  make setup    Check that required tools are installed"
	@echo "  make help     Show this message"
	@echo ""

# Verify that required shell tools are available
.PHONY: setup
setup:
	@bash $(SETUP)

# Ensure the output directory exists
$(OUTPUT_DIR):
	@mkdir -p $(OUTPUT_DIR)


