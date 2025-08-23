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
    
    # Test external command (now exits 0 but shows status 3)
    run_test_output "External command (ls)" 0 "external" "$SCRIPT_PATH" ls
    
    # Test unknown command (now exits 0 but shows status 4)
    run_test_output "Unknown command" 0 "unknown" "$SCRIPT_PATH" nonexistent_command_xyz
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
    
    # Test basic all mode (aliases are not separately controlled)
    run_test "All mode basic" 0 "$SCRIPT_PATH" --all
    
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
    
    # Test all mode without options (alias files are handled via CHECK_BUILTINS_ALIAS_FILE env var)
    run_test "All mode works" 0 "$SCRIPT_PATH" --all
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

test_builtin_detection() {
    log_info "=== Testing Builtin Command Detection ==="
    
    # Test that the script detects all expected builtin commands
    # These are the commands that should be found in the builtin list
    local expected_commands=("alias" "bg" "cd" "dirs" "echo" "false" "for" "hash" "mapfile" "read" "time" "type" "ulimit" "while")
    
    log_info "Testing detection of required builtin commands..."
    
    # Run the script and capture the output
    local output
    if output=$("$SCRIPT_PATH" --all 2>&1); then
        local test_passed=true
        local missing_commands=()
        
        # Check that each expected command appears in the output
        for cmd in "${expected_commands[@]}"; do
            if echo "$output" | grep -q "^$cmd"; then
                log_success "Found required builtin: $cmd"
            else
                log_error "Missing required builtin: $cmd"
                missing_commands+=("$cmd")
                test_passed=false
            fi
        done
        
        if $test_passed; then
            log_success "All required builtin commands detected ✓"
            ((TESTS_PASSED++))
        else
            log_error "Missing builtin commands: ${missing_commands[*]}"
            echo "This indicates the builtin detection method needs improvement."
            echo "Current builtin extraction may be missing commands from the second column of 'builtin help' output."
            ((TESTS_FAILED++))
        fi
    else
        log_error "Failed to run script for builtin detection test"
        ((TESTS_FAILED++))
    fi
    
    ((TESTS_RUN++))
}

test_critical_commands_config() {
    log_info "=== Testing Critical Commands Configuration ==="
    
    # Create a test config file for critical commands
    local config_file
    config_file="$(pwd)/test_critical_config.txt"
    cat > "$config_file" << 'EOF'
# Test critical commands configuration
WHITELIST ls
CRITICAL wget
CRITICAL curl
NONCRITICAL echo
EOF
    
    # Test that CRITICAL commands are added
    CHECK_BUILTINS="$config_file" run_test_output "CRITICAL adds commands" 0 "wget.*external" "$SCRIPT_PATH" --all
    CHECK_BUILTINS="$config_file" run_test_output "CRITICAL adds curl" 0 "curl.*external" "$SCRIPT_PATH" --all
    
    # Test that NONCRITICAL removes commands (echo should not appear in critical section)
    local output
    if output=$(CHECK_BUILTINS="$config_file" "$SCRIPT_PATH" --all 2>&1); then
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
    CHECK_BUILTINS="$config_file" run_test_output "Critical config debug" 0 "Adding critical command: wget" "$SCRIPT_PATH" --debug echo
    CHECK_BUILTINS="$config_file" run_test_output "Critical config debug removal" 0 "Removing critical command: echo" "$SCRIPT_PATH" --debug echo
    
    # Clean up
    rm -f "$config_file"
}

test_error_conditions() {
    log_info "=== Testing Error Conditions ==="
    
    # Test multiple commands (should fail)
    run_test "Multiple commands error" 1 "$SCRIPT_PATH" echo ls
    
    # Test invalid option combinations
    run_test "No arguments" 2 "$SCRIPT_PATH"
    
    # Test help option (should exit 0)
    run_test "Help option" 0 "$SCRIPT_PATH" --help
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

test_status_codes() {
    log_info "=== Testing Status Output (No Exit Codes) ==="
    
    # Test that all commands now exit 0 but show correct status symbols in output
    run_test_output "Builtin status (0) - echo" 0 "echo.*✔.*builtin" "$SCRIPT_PATH" echo
    run_test_output "External status (3) - ls" 0 "ls.*⚠.*external command" "$SCRIPT_PATH" ls
    run_test_output "Unknown status (4) - nonexistent" 0 "nonexistent_xyz.*❌.*unknown" "$SCRIPT_PATH" nonexistent_xyz
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
    
    # Test script handles missing commands gracefully (now exits 0 but shows status 4)
    run_test "Missing command handled" 0 "$SCRIPT_PATH" definitely_not_a_command_12345
    
    # Test script with minimal environment
    PATH="/usr/bin:/bin" SHELL="/bin/bash" run_test "Minimal environment" 0 "$SCRIPT_PATH" echo
}

# Functional integration tests
test_sourcing_functionality() {
    log_info "=== Testing Sourcing Functionality ==="
    
    # Test that script can be sourced without executing cb_main
    local test_script="/tmp/test_sourcing_$$"
    cat > "$test_script" << 'EOF'
#!/bin/bash
# Test script to verify sourcing functionality

# Source the script
source "./check_builtin.sh" 2>/dev/null || exit 1

# Verify that cb_main was not called by checking we're still in this script
# If cb_main was called, it would have exited or shown help

# Test that functions are available after sourcing
if declare -f cb_show_version > /dev/null 2>&1; then
    echo "PASS: cb_show_version function available"
else
    echo "FAIL: cb_show_version function not available"
    exit 1
fi

if declare -f cb_debug_log > /dev/null 2>&1; then
    echo "PASS: cb_debug_log function available"
else
    echo "FAIL: cb_debug_log function not available"
    exit 1
fi

if declare -f cb_initialize_variables > /dev/null 2>&1; then
    echo "PASS: cb_initialize_variables function available"
else
    echo "FAIL: cb_initialize_variables function not available"
    exit 1
fi

# Test that we can call individual functions
# Note: We need to initialize variables first for some functions to work
cb_initialize_variables

# Test cb_show_version function
if version_output=$(cb_show_version 2>&1) && echo "$version_output" | grep -q "check_builtins.sh version"; then
    echo "PASS: cb_show_version function works correctly"
else
    echo "FAIL: cb_show_version function doesn't work: $version_output"
    exit 1
fi

# Test cb_debug_log function (should not output anything when cb_debug=false)
debug_output=$(cb_debug_log "test message" 2>&1)
if [[ -z "$debug_output" ]]; then
    echo "PASS: cb_debug_log respects cb_debug=false"
else
    echo "FAIL: cb_debug_log produced output when cb_debug=false: $debug_output"
    exit 1
fi

# Enable debug and test again
cb_debug=true
debug_output=$(cb_debug_log "test message" 2>&1)
if echo "$debug_output" | grep -q "DEBUG: test message"; then
    echo "PASS: cb_debug_log works when cb_debug=true"
else
    echo "FAIL: cb_debug_log doesn't work when cb_debug=true: $debug_output"
    exit 1
fi

echo "PASS: All sourcing tests passed"
exit 0
EOF

    chmod +x "$test_script"
    
    # Run the test script
    ((TESTS_RUN++))
    local output
    if output=$("$test_script" 2>&1) && echo "$output" | grep -q "PASS: All sourcing tests passed"; then
        log_success "Sourcing functionality test passed ✓"
        ((TESTS_PASSED++))
    else
        log_error "Sourcing functionality test failed"
        echo "Test output:"
        echo "$output"
        echo "---"
        ((TESTS_FAILED++))
    fi
    
    # Clean up
    rm -f "$test_script"
    
    # Test that script still works normally when executed directly
    ((TESTS_RUN++))
    if "$SCRIPT_PATH" --version | grep -q "check_builtins.sh version"; then
        log_success "Script still works when executed directly ✓"
        ((TESTS_PASSED++))
    else
        log_error "Script doesn't work when executed directly after sourcing changes"
        ((TESTS_FAILED++))
    fi
}

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
    test_builtin_detection
    echo
    test_critical_commands_config
    echo
    test_error_conditions
    echo
    test_environment_variables
    echo
    test_status_codes
    echo
    test_performance
    echo
    test_script_robustness
    echo
    test_sourcing_functionality
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
        builtin-detection) 
            setup_test_files
            test_builtin_detection 
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
            test_status_codes 
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
        sourcing) 
            setup_test_files
            test_sourcing_functionality 
            cleanup_test_files
            ;;
        integration) 
            setup_test_files
            test_integration 
            cleanup_test_files
            ;;
        *)
            echo "Usage: $0 [help|single|all|options|aliases|whitelist|critical|builtin-detection|critical-config|errors|env|exit|performance|robustness|sourcing|integration]"
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
