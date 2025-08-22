# Makefile for check_builtin.sh testing

.PHONY: test test-ci test-help test-single test-all test-verbose test-summary test-ci-summary test-help-summary test-single-summary test-all-summary test-errors-summary test-integration-summary clean

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

test-integration:
	./tests/test_check_builtin.sh integration

test-integration-summary:
	@./tests/test_check_builtin.sh integration 2>&1 | sed -n '/=== Test Summary ===/,$$p'

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
	@echo "  test-errors  - Test error conditions"
	@echo "  test-errors-summary - Test error conditions (summary only)"
	@echo "  test-integration - Test integration scenarios"
	@echo "  test-integration-summary - Test integration scenarios (summary only)"
	@echo "  smoke        - Quick smoke test"
	@echo "  clean        - Clean up test artifacts"
	@echo "  help         - Show this help"
