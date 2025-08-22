# check_builtin.sh

A Bash utility to check whether commands are shell builtins, functions, aliases, or external binaries, with special focus on detecting potentially dangerous overrides of critical commands.

## Overview

This script helps system administrators and developers identify when shell builtins are being overridden by aliases, functions, or external commands. This is particularly important for security and reliability, as overriding critical commands like `cd`, `rm`, `mv`, `sudo`, etc., can lead to unexpected behavior or security vulnerabilities.

## Features

- **Single Command Check**: Verify the shell `type` and status of a specific command
- **Bulk Analysis**: Check all shell builtins for overrides
- **Critical Commands Audit**: Special focus on security-critical commands
- **Whitelist Support**: Configure exceptions for legitimate overrides
- **JSON Export**: Export results in JSON format for automation
- **Colorized Output**: Visual indicators for different command types
- **Alias File Support**: Load additional alias definitions
- **Debug Mode**: Detailed logging for troubleshooting

## Installation

1. Clone or download the script:

```bash
wget https://raw.githubusercontent.com/shadowbq/check_builtins/refs/heads/main/check_builtin.sh
chmod +x check_builtin.sh
```

2. Optionally, move to a directory in your PATH:

```bash
sudo mv check_builtin.sh /usr/local/bin/check_builtin
```

## Use Cases

### Security Audit

- Verify critical commands aren't overridden
- Audit systems for unexpected aliases or functions
- Compliance checking in production environments

### Development Environment Setup

- Ensure consistent command behavior across environments
- Detect conflicting aliases or functions
- Validate shell environment before deployment

### Shell Troubleshooting

- Diagnose unexpected command behavior
- Identify source of command overrides
- Debug shell configuration issues

### Automation

- Include in CI/CD pipelines for environment validation
- Automated security compliance checking
- System configuration drift detection

## Usage

### Basic Usage

Check a single command:

```bash
./check_builtin.sh echo
./check_builtin.sh cd
./check_builtin.sh ls
```

### Comprehensive Analysis

Check all builtins and show overrides:

```bash
./check_builtin.sh --all
```

Show user-defined functions:

```bash
./check_builtin.sh --all --functions
```

Show all aliases:

```bash
./check_builtin.sh --all --aliases
```

### Security Auditing

Run in strict mode (exits with error code if overrides found):

```bash
./check_builtin.sh --all --strict
```

### Export and Automation

Export results to JSON:

```bash
./check_builtin.sh --all --json results.json
```

Load additional aliases from a file:

```bash
./check_builtin.sh --all --alias-file ~/.my_aliases
```

### Debugging

Enable verbose debug output:

```bash
./check_builtin.sh --debug echo
./check_builtin.sh --all --debug
```

## Command Line Options

| Option | Description |
|--------|-------------|
| `[command]` | Check a single command |
| `-a, --all` | List all builtins and check for overrides |
| `--functions` | Show user-defined functions (with --all) |
| `--aliases` | Show user-defined aliases (with --all) |
| `--strict` | Exit with non-zero code if any override found |
| `--debug` | Enable detailed debug output |
| `--json <file>` | Export results to JSON file |
| `--alias-file <file>` | Source additional alias file |
| `-h, --help` | Show help message |
| `--version` | Show version information |

## Output Format

The script provides a table with the following columns:

- **COMMAND**: The command name
- **STATUS**: Visual indicator (✔ for builtin, ❌ for override, ⚠ for external)
- **INFO**: Detailed information about the command type

### Status Indicators

| Symbol | Meaning |
|--------|---------|
| ✔ | Shell builtin or keyword (safe) |
| ❌ | Function or alias override (potential issue) |
| ⚠ | External command in PATH |
| ✓ | Whitelisted override (acknowledged) |

## Exit Codes

### Single Command Mode

- `0` = Shell builtin
- `1` = Function override
- `2` = Alias override
- `3` = External command in PATH
- `4` = Unknown command
- `5` = Whitelisted override

### All Mode

- `0` = Success (no issues or --strict not used)
- `1-5` = Worst issue found (only with --strict)

### General

- `2` = Improper usage## Testing

This repository includes comprehensive testing to ensure reliability:

### Test Files
- `test_check_builtin.sh` - Full comprehensive test suite with colorized output
- `ci_test_check_builtin.sh` - CI-friendly minimal test runner
- `Makefile` - Convenient test running targets

### Running Tests

```bash
# Run comprehensive test suite
./test_check_builtin.sh

# Run CI-friendly tests
./ci_test_check_builtin.sh

# Run specific test categories
./test_check_builtin.sh help      # Test help functionality
./test_check_builtin.sh single    # Test single command mode
./test_check_builtin.sh all       # Test all mode
./test_check_builtin.sh errors    # Test error conditions

# Using Makefile
make test          # Comprehensive tests
make test-ci       # CI tests
make smoke         # Quick smoke test
make clean         # Clean test artifacts
```

The test suite covers all functionality including exit codes, error conditions, environment variables, performance, and integration scenarios.

## Configuration

### Whitelist File

Create a `.check_builtins` file in the same directory as the script to whitelist legitimate overrides:

```bash
# Comments are allowed
WHITELIST ls
WHITELIST grep
WHITELIST find
```

### Environment Variables

- `CHECK_BUILTINS_NO_RC`: Set to disable loading of bashrc files

## Critical Commands

The script pays special attention to these security-critical commands:

- `cd` - Directory navigation
- `rm` - File removal
- `mv` - File moving/renaming
- `sudo` - Privilege escalation
- `kill` - Process termination
- `sh` - Shell execution
- `bash` - Bash shell execution
- `echo` - Output display
- `printf` - Formatted output

## Examples

### Example 1: Basic Check

```bash
$ ./check_builtin.sh echo
COMMAND              STATUS INFO
-------              ------ ----
echo                 ✔      builtin
```

### Example 2: Override Detection

```bash
$ alias rm='rm -i'
$ ./check_builtin.sh rm
COMMAND              STATUS INFO
-------              ------ ----
rm                   ❌     alias → rm -i (overrides builtin)
```

### Example 3: Full System Audit

```bash
$ ./check_builtin.sh --all --strict
COMMAND              STATUS INFO
-------              ------ ----
alias                ✔      builtin
bg                   ✔      builtin
bind                 ✔      builtin
...
ls                   ❌     alias → ls --color=auto (overrides /usr/bin/ls)
...

Critical commands audit:
COMMAND              STATUS INFO
-------              ------ ----
cd                   ✔      builtin
rm                   ❌     alias → rm -i (overrides builtin)
...
```

### Example 4: JSON Export

```bash
$ ./check_builtin.sh --all --json audit.json
$ cat audit.json
[{"command":"alias","status":0,"info":"builtin"},{"command":"bg","status":0,"info":"builtin"}...]
```



## Issues and Debugging

### Common Issues

1. **Permission Denied**: Ensure the script is executable (`chmod +x check_builtin.sh`)

2. **Unexpected Results**: Use `--debug` flag to see detailed processing information

3. **Missing Commands**: Some distributions may have different builtin sets

4. **Alias Loading**: The script loads bashrc files by default; set `CHECK_BUILTINS_NO_RC=1` to disable

### Debug Mode

Use the `--debug` flag to see detailed information about command resolution:

```bash
$ ./check_builtin.sh --debug echo
DEBUG: single_command='echo' all_mode=false
DEBUG: Entering single command mode
DEBUG: check_command called with 'echo'
DEBUG: Getting type output for 'echo'
DEBUG: Got type output
DEBUG: Processing line: 'echo is a shell builtin'
...
```

## Requirements

- Bash 4.0 or later
- Standard Unix utilities (`type`, `awk`, `grep`, `sort`)

## License

MIT License - Copyright (c) 2025 shadowbq

## Contributing

Feel free to submit issues, suggestions, or improvements. The script is designed to be portable and should work across different Unix-like systems.
