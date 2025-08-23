# check_builtin.sh

A Bash utility to check whether commands are shell builtins, functions, aliases, or external binaries, with special focus on detecting potentially dangerous overrides of critical commands.

## Overview

This script helps system administrators and developers identify when shell builtins are being overridden by aliases, functions, or external commands. This is particularly important for security and reliability, as overriding critical commands like `cd`, `rm`, `mv`, `sudo`, etc., can lead to unexpected behavior or security vulnerabilities.

## Bash Command Precedence

Understanding bash command precedence is crucial for interpreting the results of this script. When you type a command in bash, the shell resolves it in this **exact order**:

### 1. **Aliases** (Highest Priority)

```bash
alias ls='ls --color=auto'
ls  # → executes: ls --color=auto
```

### 2. **Functions**

```bash
cd() { echo "Custom cd"; builtin cd "$@"; }
cd /tmp  # → executes: custom function, then builtin cd
```

### 3. **Builtins**

```bash
echo "hello"  # → executes: shell builtin echo
```

### 4. **External Commands** (Lowest Priority)

```bash
/usr/bin/ls  # → executes: external binary
```

**PATH Position Order:** When multiple external commands exist with the same name, bash searches PATH directories in order and executes the first match found. For example, if `ls` exists at both `/usr/bin/ls` (PATH position 21) and `/bin/ls` (PATH position 23), bash will execute `/usr/bin/ls` because position 21 comes before position 23 in the PATH search order - the lower the position number, the higher the precedence among external commands.

**PATH Example:**

```bash
PATH="/home/user/bin:/usr/local/bin:/usr/bin:/bin:/usr/games"

$ echo $PATH | tr ':' '\n' | head -5 | nl
1    /home/user/bin          # Position 1 (highest precedence)
2    /usr/local/bin          # Position 2
3    /usr/bin                # Position 3  
4    /bin                    # Position 4
5    /usr/games              # Position 5 (lowest precedence)
```

If a command `myapp` exists in positions 2, 3, and 5, bash will execute `/usr/local/bin/myapp` (position 2) because it appears first in the search order.

### Important Facts

- **Builtins override external commands**: Even if `/usr/bin/echo` exists, `echo` runs the builtin
- **First match wins**: bash stops at the first match in the precedence order
- **PATH position matters**: For external commands, earlier PATH entries take precedence
- **Bypass precedence**: Use `command`, `builtin`, or full paths to force specific execution

### Examples

**Builtin with external alternatives:**

```bash
$ type -a echo
echo is a shell builtin      ← This executes
echo is /usr/bin/echo        ← Available but not used
echo is /bin/echo            ← Available but not used
```

**Override chain:**

```bash
$ alias echo='echo [ALIASED]'
$ type -a echo  
echo is aliased to `echo [ALIASED]'  ← This executes
echo is a shell builtin              ← Overridden by alias
echo is /usr/bin/echo               ← Overridden by alias
```

**Force specific execution:**

```bash
builtin echo "hello"    # Force builtin
command echo "hello"    # Skip aliases/functions, use builtin or external
env echo "hello"        # Force external command
/usr/bin/echo "hello"   # Force specific external binary
```

This tool shows you the complete resolution chain and identifies which command actually executes based on these precedence rules.

**Script Output Interpretation:**

- **STATUS** indicates which type actually executes (based on precedence)
- **INFO** shows the complete detection chain with all available forms
- **Symbols**: ✔ = safe builtin/keyword, ⚠ = external command, ❌ = override detected

## Example Output

Single Command Check Mode

```bash
$ ./check_builtin.sh echo
COMMAND              STATUS INFO
-------              ------ ----
echo                 ✔ builtin | builtin external → /usr/bin/echo (PATH position 21) external → /bin/echo (PATH position 23)
```

This shows: `echo` executes as a **builtin** (✔), but external alternatives exist at `/usr/bin/echo` and `/bin/echo` which would run if the builtin were disabled.

Multi Command Check Mode

```bash
$ ./check_builtin.sh echo ls pwd
./check_builtin.sh -a
COMMAND              STATUS INFO
-------              ------ ----
!                    ✔ keyword | keyword
.                    ✔ builtin | builtin
:                    ✔ builtin | builtin
[                    ✔ builtin | builtin external → /usr/bin/[ (PATH position 21) external → /bin/[ (PATH position 23)
...snip...
bg                   ✔ builtin | builtin
bind                 ✔ builtin | builtin
break                ✔ builtin | builtin
...snip...
dirs                 ✔ builtin | builtin
disown               ✔ builtin | builtin
do                   ✔ keyword | keyword
done                 ✔ keyword | keyword
echo                 ✔ builtin | builtin external → /usr/bin/echo (PATH position 21) external → /bin/echo (PATH position 23)
elif                 ✔ keyword | keyword
else                 ✔ keyword | keyword
...snip...
until                ✔ keyword | keyword
wait                 ✔ builtin | builtin
while                ✔ keyword | keyword

Critical commands audit:
COMMAND              STATUS INFO
-------              ------ ----
cd                   ✔ builtin | builtin
rm                   ⚠ external command | external → /usr/bin/rm (PATH position 21) external → /bin/rm (PATH position 23)
mv                   ⚠ external command | external → /usr/bin/mv (PATH position 21) external → /bin/mv (PATH position 23)
sudo                 ⚠ external command | external → /usr/bin/sudo (PATH position 21) external → /bin/sudo (PATH position 23)
kill                 ✔ builtin | builtin external → /usr/bin/kill (PATH position 21) external → /bin/kill (PATH position 23)
sh                   ⚠ external command | external → /usr/bin/sh (PATH position 21) external → /bin/sh (PATH position 23)
bash                 ⚠ external command | external → /usr/bin/bash (PATH position 21) external → /bin/bash (PATH position 23)
echo                 ✔ builtin | builtin external → /usr/bin/echo (PATH position 21) external → /bin/echo (PATH position 23)
printf               ✔ builtin | builtin external → /usr/bin/printf (PATH position 21) external → /bin/printf (PATH position 23)
ls                   ⚠ external command | external → /usr/bin/ls (PATH position 21) external → /bin/ls (PATH position 23)
```

## Real-world Alias Detection

### The Challenge

When you run `./check_builtin.sh` directly, it cannot detect aliases from your current shell because aliases are not inherited by child processes. This is fundamental bash behavior - aliases only exist in the shell where they were defined.

```bash
# This won't detect your current shell's aliases
$ alias ls='ls --color=auto'
$ ./check_builtin.sh ls
COMMAND              STATUS INFO
-------              ------ ----
ls                   ⚠      external command | external → /usr/bin/ls
```

### Real-world Usage

To detect aliases from your current shell, source the script first and then use the export function:

```bash
source check_builtin.sh
cb_export_current_aliases ls

COMMAND              STATUS INFO
-------              ------ ----
ls                   ❌     alias override | alias → LC_COLLATE=C ls --color=auto | external → /usr/bin/ls
```

This will properly inherit all aliases from your current shell session and check the specified command.

**✅ SAFE usage:**

- Always use `cb_export_current_aliases()` only when the script is **sourced** (`source check_builtin.sh`)
- The script includes safety checks to prevent accidental misuse


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

### Critical Commands

Default Critical Commands

```bash
CRITICAL=("cd" "rm" "mv" "sudo" "kill" "sh" "bash" "echo" "printf")
```

Add additional critical commands to this section as needed one per line.

```bash
# Comments are allowed
CRITICAL lsusb
CRITICAL curl
```

Remove commands from this section if they are deemed non-critical one per line.

```bash
NONCRITICAL awk
NONCRITICAL sed
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
