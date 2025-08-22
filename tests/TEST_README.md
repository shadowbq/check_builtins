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
# Test help functionality
./test_check_builtin.sh help

# Test single command mode
./test_check_builtin.sh single

# Test all mode functionality
./test_check_builtin.sh all

# Test command options
./test_check_builtin.sh options

# Test alias file loading
./test_check_builtin.sh aliases

# Test whitelist functionality
./test_check_builtin.sh whitelist

# Test critical commands audit
./test_check_builtin.sh critical

# Test builtin command detection
./test_check_builtin.sh builtin-detection

# Test critical commands configuration
./test_check_builtin.sh critical-config

# Test error conditions
./test_check_builtin.sh errors

# Test environment variables
./test_check_builtin.sh env

# Test exit codes
./test_check_builtin.sh exit

# Test performance
./test_check_builtin.sh performance

# Test script robustness
./test_check_builtin.sh robustness

# Test integration
./test_check_builtin.sh integration
```

## Test Coverage

The test suite covers:

### Core Functionality
- ✅ Help display (`-h`, `--help`)
- ✅ Single command checking with all exit codes (0-4)
- ✅ All mode functionality (`--all`, `-a`)
- ✅ Critical commands audit

### Command Options
- ✅ Strict mode (`--strict`)
- ✅ Debug mode (`--debug`)
- ✅ Functions display (`--functions`)
- ✅ Aliases display (`--aliases`)
- ✅ JSON output (`--json`)
- ✅ Alias file loading (`--alias-file`)

### Error Handling
- ✅ Multiple commands error handling
- ✅ No arguments error handling
- ✅ Non-existent files handling

### Environment Testing
- ✅ Environment variable support (`CHECK_BUILTINS_NO_RC`)
- ✅ Different PATH configurations
- ✅ Minimal environment testing

### Integration Tests
- ✅ Critical commands detection
- ✅ External commands identification
- ✅ Builtin commands verification
- ✅ Required builtin detection (alias, bg, cd, dirs, echo, false, for, hash, mapfile, read, time, type, ulimit, while)

### Performance
- ✅ Performance regression testing (< 10 seconds threshold)

### Robustness
- ✅ Limited PATH handling
- ✅ Missing command handling
- ✅ Whitelist functionality

## Exit Codes

The test script uses standard exit codes:
- `0` - All tests passed
- `1` - Some tests failed

## Test Output

The test suite provides:
- Colorized output for easy reading
- Individual test results with ✓/✗ indicators
- Detailed failure information when tests fail
- Summary statistics (tests run, passed, failed, success rate)
- Support for running individual test categories

## Continuous Integration

This test suite is designed to be run in CI/CD pipelines to ensure the `check_builtin.sh` script continues to work correctly across different environments and shell configurations.

## Adding New Tests

To add new tests:

1. Create a new test function following the naming pattern `test_*`
2. Use the helper functions `run_test()` and `run_test_output()`
3. Add the test to the main test runner function
4. Add it to the individual test selector case statement

Example:
```bash
test_new_functionality() {
    log_info "=== Testing New Functionality ==="
    
    run_test_output "New feature test" 0 "expected_output" "$SCRIPT_PATH" --new-option
}
```

## Dependencies

The test suite requires:
- Bash 4.0+
- Basic Unix utilities (grep, date, etc.)
- The `check_builtin.sh` script in the same directory
