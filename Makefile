# Makefile for check_builtin.sh testing

.PHONY: test test-ci test-help test-single test-all test-options test-aliases test-whitelist test-critical test-builtin-detection test-critical-config test-errors test-env test-exit test-performance test-robustness test-integration test-sourcing test-verbose test-summary test-ci-summary test-help-summary test-single-summary test-all-summary test-options-summary test-aliases-summary test-whitelist-summary test-critical-summary test-builtin-detection-summary test-critical-config-summary test-errors-summary test-env-summary test-exit-summary test-performance-summary test-robustness-summary test-integration-summary test-sourcing-summary clean

# Default target - run comprehensive tests
test:
	@echo "Running comprehensive test suite..."
	./tests/test_check_builtin.sh

# Summary-only comprehensive tests
test-summary:
	@echo "Running comprehensive test suite (summary only)..."
	@./tests/test_check_builtin.sh 2>&1 | sed -n '/=== Test Summary ===/,$$p'

# CI-friendly test run
test-ci:
	@echo "Running CI test suite..."
	./tests/ci_test_check_builtin.sh

# CI-friendly test run (summary only)
test-ci-summary:
	@echo "Running CI test suite (summary only)..."
	@./tests/ci_test_check_builtin.sh 2>&1 | sed -n '/Test Results:/,$$p'

# Run specific test categories
test-help:
	./tests/test_check_builtin.sh help

test-help-summary:
	@./tests/test_check_builtin.sh help 2>&1 | sed -n '/=== Test Summary ===/,$$p'

test-single:
	./tests/test_check_builtin.sh single

test-single-summary:
	@./tests/test_check_builtin.sh single 2>&1 | sed -n '/=== Test Summary ===/,$$p'

test-all:
	./tests/test_check_builtin.sh all

test-all-summary:
	@./tests/test_check_builtin.sh all 2>&1 | sed -n '/=== Test Summary ===/,$$p'

test-errors:
	./tests/test_check_builtin.sh errors

test-errors-summary:
	@./tests/test_check_builtin.sh errors 2>&1 | sed -n '/=== Test Summary ===/,$$p'

test-options:
	./tests/test_check_builtin.sh options

test-options-summary:
	@./tests/test_check_builtin.sh options 2>&1 | sed -n '/=== Test Summary ===/,$$p'

test-aliases:
	./tests/test_check_builtin.sh aliases

test-aliases-summary:
	@./tests/test_check_builtin.sh aliases 2>&1 | sed -n '/=== Test Summary ===/,$$p'

test-whitelist:
	./tests/test_check_builtin.sh whitelist

test-whitelist-summary:
	@./tests/test_check_builtin.sh whitelist 2>&1 | sed -n '/=== Test Summary ===/,$$p'

test-critical:
	./tests/test_check_builtin.sh critical

test-critical-summary:
	@./tests/test_check_builtin.sh critical 2>&1 | sed -n '/=== Test Summary ===/,$$p'

test-builtin-detection:
	./tests/test_check_builtin.sh builtin-detection

test-builtin-detection-summary:
	@./tests/test_check_builtin.sh builtin-detection 2>&1 | sed -n '/=== Test Summary ===/,$$p'

test-critical-config:
	./tests/test_check_builtin.sh critical-config

test-critical-config-summary:
	@./tests/test_check_builtin.sh critical-config 2>&1 | sed -n '/=== Test Summary ===/,$$p'

test-env:
	./tests/test_check_builtin.sh env

test-env-summary:
	@./tests/test_check_builtin.sh env 2>&1 | sed -n '/=== Test Summary ===/,$$p'

test-exit:
	./tests/test_check_builtin.sh exit

test-exit-summary:
	@./tests/test_check_builtin.sh exit 2>&1 | sed -n '/=== Test Summary ===/,$$p'

test-performance:
	./tests/test_check_builtin.sh performance

test-performance-summary:
	@./tests/test_check_builtin.sh performance 2>&1 | sed -n '/=== Test Summary ===/,$$p'

test-robustness:
	./tests/test_check_builtin.sh robustness

test-robustness-summary:
	@./tests/test_check_builtin.sh robustness 2>&1 | sed -n '/=== Test Summary ===/,$$p'

test-integration:
	./tests/test_check_builtin.sh integration

test-integration-summary:
	@./tests/test_check_builtin.sh integration 2>&1 | sed -n '/=== Test Summary ===/,$$p'

test-sourcing:
	./tests/test_check_builtin.sh sourcing

test-sourcing-summary:
	@./tests/test_check_builtin.sh sourcing 2>&1 | sed -n '/=== Test Summary ===/,$$p'

# Verbose test run
test-verbose:
	@echo "Running verbose tests..."
	./tests/test_check_builtin.sh

# Clean up any test artifacts
clean:
	@echo "Cleaning up test artifacts..."
	rm -f ./tests/test_aliases.sh .check_builtins test_output.json

# Quick smoke test
smoke:
	@echo "Running smoke tests..."
	./check_builtin.sh --help > /dev/null
	./check_builtin.sh echo > /dev/null
	./check_builtin.sh --all > /dev/null
	@echo "Smoke tests passed ✓"

# Show help
help:
	@echo "Available targets:"
	@echo "  test         - Run comprehensive test suite (default)"
	@echo "  test-summary - Run comprehensive test suite (summary only)"
	@echo "  test-ci      - Run CI-friendly test suite"
	@echo "  test-ci-summary - Run CI-friendly test suite (summary only)"
	@echo "  test-help    - Test help functionality"
	@echo "  test-help-summary - Test help functionality (summary only)"
	@echo "  test-single  - Test single command mode"
	@echo "  test-single-summary - Test single command mode (summary only)"
	@echo "  test-all     - Test all mode functionality"
	@echo "  test-all-summary - Test all mode functionality (summary only)"
	@echo "  test-options - Test command options"
	@echo "  test-options-summary - Test command options (summary only)"
	@echo "  test-aliases - Test alias file loading"
	@echo "  test-aliases-summary - Test alias file loading (summary only)"
	@echo "  test-whitelist - Test whitelist functionality"
	@echo "  test-whitelist-summary - Test whitelist functionality (summary only)"
	@echo "  test-critical - Test critical commands audit"
	@echo "  test-critical-summary - Test critical commands audit (summary only)"
	@echo "  test-builtin-detection - Test builtin command detection"
	@echo "  test-builtin-detection-summary - Test builtin command detection (summary only)"
	@echo "  test-critical-config - Test critical commands configuration"
	@echo "  test-critical-config-summary - Test critical commands configuration (summary only)"
	@echo "  test-errors  - Test error conditions"
	@echo "  test-errors-summary - Test error conditions (summary only)"
	@echo "  test-env     - Test environment variables"
	@echo "  test-env-summary - Test environment variables (summary only)"
	@echo "  test-exit    - Test exit codes"
	@echo "  test-exit-summary - Test exit codes (summary only)"
	@echo "  test-performance - Test performance characteristics"
	@echo "  test-performance-summary - Test performance characteristics (summary only)"
	@echo "  test-robustness - Test script robustness"
	@echo "  test-robustness-summary - Test script robustness (summary only)"
	@echo "  test-integration - Test integration scenarios"
	@echo "  test-integration-summary - Test integration scenarios (summary only)"
	@echo "  test-sourcing - Test sourcing functionality"
	@echo "  test-sourcing-summary - Test sourcing functionality (summary only)"
	@echo "  smoke        - Quick smoke test"
	@echo "  clean        - Clean up test artifacts"
	@echo "  help         - Show this help"
