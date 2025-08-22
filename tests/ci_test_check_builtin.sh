#!/usr/bin/env bash
# ci_test_check_builtin.sh - CI-friendly test runner for check_builtin.sh
# This script provides minimal output suitable for CI/CD pipelines

set -u

SCRIPT_PATH="./check_builtin.sh"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

if [[ ! -x "$SCRIPT_PATH" ]]; then
    echo "FATAL: $SCRIPT_PATH not found or not executable"
    exit 1
fi

# Simple test runner
run_ci_test() {
    local test_name="$1"
    local expected_exit="$2"
    shift 2
    local cmd=("$@")
    
    ((TOTAL_TESTS++))
    
    local actual_exit=0
    "${cmd[@]}" >/dev/null 2>&1 || actual_exit=$?
    
    if [[ $actual_exit -eq $expected_exit ]]; then
        ((PASSED_TESTS++))
        echo "PASS: $test_name"
        return 0
    else
        ((FAILED_TESTS++))
        echo "FAIL: $test_name (exit $actual_exit, expected $expected_exit)"
        return 1
    fi
}

# Create minimal test files
cat > test_aliases.sh << 'EOF'
alias ls='ls --color=auto'
EOF

cat > .check_builtins << 'EOF'
whitelist ls
EOF

echo "Running check_builtin.sh test suite..."

# Core functionality tests
run_ci_test "help_display" 0 "$SCRIPT_PATH" --help
run_ci_test "builtin_command" 0 "$SCRIPT_PATH" echo
run_ci_test "external_command" 3 "$SCRIPT_PATH" ls
run_ci_test "unknown_command" 4 "$SCRIPT_PATH" nonexistent_xyz
run_ci_test "all_mode" 0 "$SCRIPT_PATH" --all
run_ci_test "strict_mode" 0 "$SCRIPT_PATH" --all --strict
run_ci_test "debug_mode" 0 "$SCRIPT_PATH" --debug echo
run_ci_test "json_output" 0 "$SCRIPT_PATH" --all --json /tmp/test.json
run_ci_test "alias_file" 0 "$SCRIPT_PATH" --alias-file test_aliases.sh --all
run_ci_test "multiple_args_error" 1 "$SCRIPT_PATH" echo ls
run_ci_test "no_args_error" 2 "$SCRIPT_PATH"

# Clean up
rm -f test_aliases.sh .check_builtins /tmp/test.json

# Results
echo ""
echo "Test Results:"
echo "  Total: $TOTAL_TESTS"
echo "  Passed: $PASSED_TESTS"
echo "  Failed: $FAILED_TESTS"

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo "SUCCESS: All tests passed"
    exit 0
else
    echo "FAILURE: $FAILED_TESTS test(s) failed"
    exit 1
fi
