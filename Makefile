# Makefile for check_builtin.sh testing

.PHONY: test test-ci test-help test-single test-all test-verbose clean

# Default target - run comprehensive tests
test:
	@echo "Running comprehensive test suite..."
	./tests/test_check_builtin.sh

# CI-friendly test run
test-ci:
	@echo "Running CI test suite..."
	./tests/ci_test_check_builtin.sh

# Run specific test categories
test-help:
	./tests/test_check_builtin.sh help

test-single:
	./tests/test_check_builtin.sh single

test-all:
	./tests/test_check_builtin.sh all

test-errors:
	./tests/test_check_builtin.sh errors

test-integration:
	./tests/test_check_builtin.sh integration

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
	@echo "  test-ci      - Run CI-friendly test suite"
	@echo "  test-help    - Test help functionality"
	@echo "  test-single  - Test single command mode"
	@echo "  test-all     - Test all mode functionality"
	@echo "  test-errors  - Test error conditions"
	@echo "  test-integration - Test integration scenarios"
	@echo "  smoke        - Quick smoke test"
	@echo "  clean        - Clean up test artifacts"
	@echo "  help         - Show this help"
