# Test Suite for check_builtin.sh

This directory contains a comprehensive test suite for the `check_builtin.sh` script to ensure its reliability and correct functionality.

## Files

- `check_builtin.sh` - The main script being tested
- `test_check_builtin.sh` - Comprehensive test suite
- `README.md` - Documentation

## Running Tests

### Run All Tests
```bash
./test_check_builtin.sh
```

### Run Specific Test Categories
```bash
./test_check_builtin.sh [category]
```

Available categories: `help`, `single`, `all`, `options`, `aliases`, `whitelist`, `critical`, `builtin-detection`, `critical-config`, `errors`, `env`, `exit`, `performance`, `robustness`, `sourcing`, `integration`

## Test Coverage

The test suite provides comprehensive coverage including:

- **Core functionality**: Help system, single/all command modes, critical commands audit
- **Command options**: All CLI flags (`--strict`, `--debug`, `--functions`, `--aliases`, `--json`, `--alias-file`)
- **Error handling**: Invalid arguments, missing files, edge cases
- **Environment testing**: Various PATH configurations, environment variables, minimal environments
- **Integration**: End-to-end testing of real command detection and classification
- **Performance**: Execution time validation (< 10 seconds)
- **Robustness**: Limited environments, missing commands, different shell configurations
- **Library functionality**: Script sourcing, individual function calls, backward compatibility

Total test coverage includes 40+ individual tests across 16 test categories.

## Test Functions Reference

The test suite includes 16 comprehensive test functions:

**Core Tests**: `help`, `single`, `all`, `options`, `aliases`, `whitelist`, `critical`  
**Advanced Tests**: `builtin-detection`, `critical-config`, `errors`, `env`, `exit`  
**Quality Tests**: `performance`, `robustness`, `sourcing`, `integration`

Each test function thoroughly validates its respective functionality with multiple test cases, proper exit code verification, and output validation. Use `./test_check_builtin.sh [function-name]` to run individual test categories.

## Test Helper Functions

Key helper functions for consistent testing:
- `run_test()` / `run_test_output()` - Execute commands and verify results
- `setup_test_files()` / `cleanup_test_files()` - Manage test environment
- `log_*()` functions - Provide colorized test output

## Exit Codes

The test script uses standard exit codes:
- `0` - All tests passed
- `1` - Some tests failed

## Using check_builtin.sh as a Library

The script supports sourcing for library usage:

```bash
source ../check_builtin.sh
initialize_variables
show_version
check_command "ls"
```

## Test Output & CI

- Colorized output with ✓/✗ indicators and detailed failure information
- Summary statistics (tests run, passed, failed, success rate)
- Designed for CI/CD pipeline integration

## Adding New Tests

1. Create `test_*` function using `run_test()` / `run_test_output()` helpers
2. Add to main test runner and case statement

## Dependencies

- Bash 4.0+, basic Unix utilities, `check_builtin.sh` script
