#!/usr/bin/env bash
# test_check_builtin.sh - Comprehensive test suite for check_builtin.sh
# This script tests all functionality without sourcing check_builtin.sh

# Note: Not using 'set -euo pipefail' to allow tests to fail gracefully
set -u  # Only fail on unset variables

# Color codes for output
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
BOLD="\033[1m"
RESET="\033[0m"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test script path
SCRIPT_PATH="$(pwd)/check_builtin.sh"
if [[ ! -x "$SCRIPT_PATH" ]]; then
    echo -e "${RED}ERROR: $SCRIPT_PATH not found or not executable${RESET}" >&2
    exit 1
fi

# Utility functions
log_info() {
    echo -e "${BLUE}[INFO]${RESET} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${RESET} $*"
}

log_error() {
    echo -e "${RED}[FAIL]${RESET} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${RESET} $*"
}

# Simple test helper function - just check exit codes
run_test() {
    local test_name="$1"
    local expected_exit_code="$2"
    shift 2
    local cmd=("$@")
    
    ((TESTS_RUN++))
    log_info "Running test: $test_name"
    
    local actual_exit_code=0
    local output
    if output=$("${cmd[@]}" 2>&1); then
        actual_exit_code=0
    else
        actual_exit_code=$?
    fi
    
    if [[ $actual_exit_code -eq $expected_exit_code ]]; then
        log_success "$test_name - Exit code: $actual_exit_code ✓"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$test_name - Exit code: $actual_exit_code (expected: $expected_exit_code)"
        echo "Command: ${cmd[*]}"
        echo "Output:"
        echo "$output"
        echo "---"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test helper for checking output contains expected text
run_test_output() {
    local test_name="$1"
    local expected_exit_code="$2"
    local expected_text="$3"
    shift 3
    local cmd=("$@")
    
    ((TESTS_RUN++))
    log_info "Running test: $test_name"
    
    local actual_exit_code=0
    local output
    if output=$("${cmd[@]}" 2>&1); then
        actual_exit_code=0
    else
        actual_exit_code=$?
    fi
    
    local test_passed=true
    
    # Check exit code
    if [[ $actual_exit_code -ne $expected_exit_code ]]; then
        log_error "$test_name - Exit code: $actual_exit_code (expected: $expected_exit_code)"
        test_passed=false
    fi
    
    # Check output contains expected text
    if [[ -n "$expected_text" ]] && ! echo "$output" | grep -q "$expected_text"; then
        log_error "$test_name - Output doesn't contain: '$expected_text'"
        echo "Actual output:"
        echo "$output"
        echo "---"
        test_passed=false
    fi
    
    if $test_passed; then
        log_success "$test_name - Exit code: $actual_exit_code, Output contains expected text ✓"
        ((TESTS_PASSED++))
        return 0
    else
        ((TESTS_FAILED++))
        return 1
    fi
}

# Create temporary test files
setup_test_files() {
    log_info "Setting up test files..."
    
    # Create a test alias file
    cat > test_aliases.sh << 'EOF'
alias test_alias='echo "test alias"'
alias ls='ls --color=auto'
EOF
    
    # Create a test whitelist config
    cat > .check_builtins << 'EOF'
# Test whitelist configuration
WHITELIST ls
WHITELIST test_alias
EOF
}

cleanup_test_files() {
    log_info "Cleaning up test files..."
    rm -f test_aliases.sh .check_builtins test_output.json
}

# Test functions
test_help_functionality() {
    log_info "=== Testing Help Functionality ==="
    
    run_test_output "Help with -h" 0 "Usage:" "$SCRIPT_PATH" -h
    run_test_output "Help with --help" 0 "Usage:" "$SCRIPT_PATH" --help
}

test_single_command_mode() {
    log_info "=== Testing Single Command Mode ==="
    
    # Test builtin command
    run_test_output "Builtin command (echo)" 0 "builtin" "$SCRIPT_PATH" echo
    
    # Test external command  
    run_test_output "External command (ls)" 3 "external" "$SCRIPT_PATH" ls
    
    # Test unknown command
    run_test_output "Unknown command" 4 "unknown" "$SCRIPT_PATH" nonexistent_command_xyz
}

test_all_mode() {
    log_info "=== Testing All Mode ==="
    
    run_test_output "All mode basic" 0 "COMMAND" "$SCRIPT_PATH" --all
    run_test_output "All mode with -a" 0 "STATUS" "$SCRIPT_PATH" -a
}

test_options() {
    log_info "=== Testing Command Options ==="
    
    # Test strict mode (should pass if no overrides)
    run_test "Strict mode" 0 "$SCRIPT_PATH" --all --strict
    
    # Test debug mode
    run_test_output "Debug mode" 0 "DEBUG:" "$SCRIPT_PATH" --debug echo
    
    # Test functions display
    run_test_output "Show functions" 0 "User-defined functions:" "$SCRIPT_PATH" --all --functions
    
    # Test aliases display
    run_test_output "Show aliases" 0 "Active aliases:" "$SCRIPT_PATH" --all --aliases
    
    # Test JSON output
    run_test "JSON output" 0 "$SCRIPT_PATH" --all --json test_output.json
    if [[ -f test_output.json ]]; then
        if grep -q "command" test_output.json; then
            log_success "JSON file contains expected content ✓"
        else
            log_error "JSON file doesn't contain expected content"
            ((TESTS_FAILED++))
        fi
    else
        log_error "JSON file was not created"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_alias_file_loading() {
    log_info "=== Testing Alias File Loading ==="
    
    # Test with alias file
    run_test "Load alias file" 0 "$SCRIPT_PATH" --alias-file test_aliases.sh --all
}

test_whitelist_functionality() {
    log_info "=== Testing Whitelist Functionality ==="
    
    # This test requires the whitelist file to be present
    if [[ -f .check_builtins ]]; then
        run_test "Whitelist functionality" 0 "$SCRIPT_PATH" --all
    else
        log_warning "Skipping whitelist test - no .check_builtins file"
    fi
}

test_critical_commands() {
    log_info "=== Testing Critical Commands Audit ==="
    
    run_test_output "Critical commands audit" 0 "Critical commands audit:" "$SCRIPT_PATH" --all
}

test_critical_commands_config() {
    log_info "=== Testing Critical Commands Configuration ==="
    
    # Create a test config file for critical commands
    cat > test_critical_config.txt << 'EOF'
# Test critical commands configuration
WHITELIST ls
CRITICAL wget
CRITICAL curl
NONCRITICAL echo
EOF
    
    # Test that CRITICAL commands are added
    CHECK_BUILTINS="test_critical_config.txt" run_test_output "CRITICAL adds commands" 0 "wget.*external" "$SCRIPT_PATH" --all
    CHECK_BUILTINS="test_critical_config.txt" run_test_output "CRITICAL adds curl" 0 "curl.*external" "$SCRIPT_PATH" --all
    
    # Test that NONCRITICAL removes commands (echo should not appear in critical section)
    local output
    if output=$(CHECK_BUILTINS="test_critical_config.txt" "$SCRIPT_PATH" --all 2>&1); then
        if echo "$output" | grep -A 20 "Critical commands audit:" | grep -q "^echo"; then
            log_error "NONCRITICAL test failed - echo still appears in critical commands"
            ((TESTS_FAILED++))
        else
            log_success "NONCRITICAL removes commands - echo not in critical list ✓"
            ((TESTS_PASSED++))
        fi
    else
        log_error "NONCRITICAL test failed - command execution failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
    
    # Test debug output shows config processing
    CHECK_BUILTINS="test_critical_config.txt" run_test_output "Critical config debug" 0 "Adding critical command: wget" "$SCRIPT_PATH" --debug echo
    CHECK_BUILTINS="test_critical_config.txt" run_test_output "Critical config debug removal" 0 "Removing critical command: echo" "$SCRIPT_PATH" --debug echo
    
    # Clean up
    rm -f test_critical_config.txt
}

test_error_conditions() {
    log_info "=== Testing Error Conditions ==="
    
    # Test multiple commands (should fail)
    run_test "Multiple commands error" 1 "$SCRIPT_PATH" echo ls
    
    # Test invalid option combinations
    run_test "No arguments" 2 "$SCRIPT_PATH"
    
    # Test non-existent alias file (should not fail)
    run_test "Non-existent alias file" 0 "$SCRIPT_PATH" --alias-file /nonexistent/file --all
}

test_environment_variables() {
    log_info "=== Testing Environment Variables ==="
    
    # Test with CHECK_BUILTINS_NO_RC set
    CHECK_BUILTINS_NO_RC=1 run_test "No RC loading" 0 "$SCRIPT_PATH" echo
    
    # Test CHECK_BUILTINS environment variable for custom config path
    log_info "Testing CHECK_BUILTINS environment variable..."
    
    # Create a temporary config file
    local temp_config="/tmp/test_check_builtins_$$"
    cat > "$temp_config" << 'EOF'
# Test configuration from environment variable
WHITELIST test_env_command
WHITELIST ls
EOF
    
    # Test that the environment variable config is found and used
    CHECK_BUILTINS="$temp_config" run_test_output "Custom config via ENV" 0 "DEBUG.*Found config file.*$temp_config" "$SCRIPT_PATH" --debug echo
    
    # Test with non-existent config path in environment
    CHECK_BUILTINS="/nonexistent/config/file" run_test "Non-existent ENV config" 0 "$SCRIPT_PATH" echo
    
    # Test that config in tests directory is found when no ENV is set
    # (since we have .check_builtins in tests/ directory)
    cd tests 2>/dev/null || true
    if [[ -f ".check_builtins" ]]; then
        run_test_output "Config from tests directory" 0 "DEBUG.*Found config file.*\\.check_builtins" "$SCRIPT_PATH" --debug echo
    fi
    cd .. 2>/dev/null || true
    
    # Clean up
    rm -f "$temp_config"
}

test_exit_codes() {
    log_info "=== Testing Exit Codes ==="
    
    # Test various exit codes in single command mode
    run_test "Builtin exit code (0)" 0 "$SCRIPT_PATH" echo
    run_test "External exit code (3)" 3 "$SCRIPT_PATH" ls
    run_test "Unknown exit code (4)" 4 "$SCRIPT_PATH" nonexistent_xyz
}

# Performance test
test_performance() {
    log_info "=== Testing Performance ==="
    
    local start_time end_time duration
    start_time=$(date +%s)
    
    "$SCRIPT_PATH" --all > /dev/null 2>&1 || true
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log_info "Performance test completed in ${duration}s"
    
    # Arbitrary performance threshold (10 seconds)
    if (( duration < 10 )); then
        log_success "Performance test passed (< 10s) ✓"
        ((TESTS_PASSED++))
    else
        log_warning "Performance test: duration ${duration}s (> 10s)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_script_robustness() {
    log_info "=== Testing Script Robustness ==="
    
    # Test script can handle different PATH environments
    PATH="/usr/bin:/bin" run_test "Limited PATH" 0 "$SCRIPT_PATH" echo
    
    # Test script handles missing commands gracefully
    run_test "Missing command handled" 4 "$SCRIPT_PATH" definitely_not_a_command_12345
    
    # Test script with minimal environment
    PATH="/usr/bin:/bin" SHELL="/bin/bash" run_test "Minimal environment" 0 "$SCRIPT_PATH" echo
}

# Functional integration tests
test_integration() {
    log_info "=== Integration Tests ==="
    
    # Test that critical commands are actually checked
    if "$SCRIPT_PATH" --all | grep -q "cd.*builtin"; then
        log_success "Critical command 'cd' is correctly identified as builtin ✓"
        ((TESTS_PASSED++))
    else
        log_error "Critical command 'cd' not found or not identified as builtin"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
    
    # Test that external commands are identified
    if "$SCRIPT_PATH" ls | grep -q "external"; then
        log_success "External command 'ls' correctly identified ✓"
        ((TESTS_PASSED++))
    else
        log_error "External command 'ls' not correctly identified"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# Main test runner
main() {
    echo -e "${BOLD}=== check_builtin.sh Test Suite ===${RESET}"
    echo "Testing script: $SCRIPT_PATH"
    echo "Working directory: $(pwd)"
    echo "Date: $(date)"
    echo
    
    # Verify script exists and is executable
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        log_error "Script not found: $SCRIPT_PATH"
        exit 1
    fi
    
    if [[ ! -x "$SCRIPT_PATH" ]]; then
        log_error "Script not executable: $SCRIPT_PATH"
        exit 1
    fi
    
    setup_test_files
    
    # Run all tests
    test_help_functionality
    echo
    test_single_command_mode
    echo
    test_all_mode
    echo
    test_options
    echo
    test_alias_file_loading
    echo
    test_whitelist_functionality
    echo
    test_critical_commands
    echo
    test_critical_commands_config
    echo
    test_error_conditions
    echo
    test_environment_variables
    echo
    test_exit_codes
    echo
    test_performance
    echo
    test_script_robustness
    echo
    test_integration
    
    cleanup_test_files
    
    # Summary
    echo
    echo -e "${BOLD}=== Test Summary ===${RESET}"
    echo "Tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${RESET}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${RESET}"
    
    local success_rate=0
    if (( TESTS_RUN > 0 )); then
        success_rate=$(( (TESTS_PASSED * 100) / TESTS_RUN ))
    fi
    echo "Success rate: ${success_rate}%"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ All tests passed!${RESET}"
        exit 0
    else
        echo -e "${RED}${BOLD}✗ Some tests failed!${RESET}"
        echo "Please check the output above for details."
        exit 1
    fi
}

# Allow running specific test functions
if [[ $# -gt 0 ]]; then
    case "$1" in
        help) 
            setup_test_files
            test_help_functionality 
            cleanup_test_files
            ;;
        single) 
            setup_test_files
            test_single_command_mode 
            cleanup_test_files
            ;;
        all) 
            setup_test_files
            test_all_mode 
            cleanup_test_files
            ;;
        options) 
            setup_test_files
            test_options 
            cleanup_test_files
            ;;
        aliases) 
            setup_test_files
            test_alias_file_loading 
            cleanup_test_files
            ;;
        whitelist) 
            setup_test_files
            test_whitelist_functionality 
            cleanup_test_files
            ;;
        critical) 
            setup_test_files
            test_critical_commands 
            cleanup_test_files
            ;;
        critical-config) 
            setup_test_files
            test_critical_commands_config 
            cleanup_test_files
            ;;
        errors) 
            setup_test_files
            test_error_conditions 
            cleanup_test_files
            ;;
        env) 
            setup_test_files
            test_environment_variables 
            cleanup_test_files
            ;;
        exit) 
            setup_test_files
            test_exit_codes 
            cleanup_test_files
            ;;
        performance) 
            setup_test_files
            test_performance 
            cleanup_test_files
            ;;
        robustness) 
            setup_test_files
            test_script_robustness 
            cleanup_test_files
            ;;
        integration) 
            setup_test_files
            test_integration 
            cleanup_test_files
            ;;
        *)
            echo "Usage: $0 [help|single|all|options|aliases|whitelist|critical|critical-config|errors|env|exit|performance|robustness|integration]"
            echo "Or run without arguments to run all tests"
            exit 1
            ;;
    esac
    
    # Show summary for individual test runs
    echo
    echo -e "${BOLD}=== Test Summary ===${RESET}"
    echo "Tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${RESET}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${RESET}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ Tests passed!${RESET}"
        exit 0
    else
        echo -e "${RED}${BOLD}✗ Some tests failed!${RESET}"
        exit 1
    fi
else
    main
fi
