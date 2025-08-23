#!/usr/bin/env bash
# MIT License - Copyright (c) 2025 shadowbq
set -euo pipefail
shopt -s expand_aliases

# ---------Constants---------
VERSION="1.3.0"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BOLD="\033[1m"
RESET="\033[0m"
CHECKMARK="${GREEN}✔${RESET}"
CROSS="${RED}❌${RESET}"
WARN="${YELLOW}⚠${RESET}"



# -------- Load exported alias file --------
cb_load_exported_aliases() {
    # Load aliases from parent shell if available (but don't load .bashrc files)
    if [[ -n "${CHECK_BUILTINS_ALIAS_FILE:-}" && -f "${CHECK_BUILTINS_ALIAS_FILE}" ]]; then
        cb_debug_log "Loading aliases from parent shell: ${CHECK_BUILTINS_ALIAS_FILE}"
        
        # Enable alias expansion for loading and detection
        shopt -s expand_aliases
        
        # Debug: show file contents
        if $cb_debug; then
            cb_debug_log "Alias file contents:"
            cat "${CHECK_BUILTINS_ALIAS_FILE}" 2>/dev/null || true
        fi
        
        # shellcheck disable=SC1090
        source "${CHECK_BUILTINS_ALIAS_FILE}" 2>/dev/null || true
        
        # Debug: check if alias was loaded
        if $cb_debug; then
            cb_debug_log "Aliases after loading:"
            alias 2>/dev/null || true
            cb_debug_log "Direct alias check for ls:"
            alias ls 2>/dev/null || cb_debug_log "No ls alias found"
        fi
    fi
}


# -------- Version --------
cb_show_version() {
    builtin echo "check_builtins.sh version $VERSION"
    builtin echo "MIT License - Copyright (c) 2025 shadowbq"
}

# -------- Help --------
cb_show_help() {
    command cat <<EOF
Usage:
  check_builtins.sh [command]       # check a single command
  check_builtins.sh -a|--all        # list all builtins and overrides
    Options:
      --functions                  # show user-defined functions
      --strict                     # report worst status found in all mode
      --debug                      # enable debug output
      --json <file>                # export results to JSON
  check_builtins.sh -h|--help      # show this help
  check_builtins.sh --version      # show version information

Real-world alias detection:
  The script cannot detect aliases from your current shell when run directly.
  To inherit your shell's aliases, use this method:
  
  source check_builtin.sh
  cb_export_current_aliases [command]
  
  Example:
    source check_builtin.sh
    cb_export_current_aliases ls

Configuration file (.check_builtins):
  WHITELIST <command>              # whitelist a command override
  CRITICAL <command>               # add command to critical commands list
  NONCRITICAL <command>            # remove command from critical commands list

Status codes (based on bash precedence order):
  Single command mode:
    0 = builtin/keyword (✔)         # native shell commands
    1 = function override (⚠)       # user-defined function overrides
    2 = alias override (⚠)          # user-defined alias overrides  
    3 = external command (⚠)        # external executables in PATH
    4 = unknown (❌)                # command not found
    5 = whitelisted override (✓)    # approved overrides
  All mode:
    Reports status numbers but always exits 0 for success
  General:
    2 = improper usage

INFO column shows full detection chain:
  - Shows all detected forms (alias → function → builtin → external)
  - Separated by " | " to show the complete resolution path
  - External commands include PATH position for transparency
EOF
}

# -------- Initialize variables --------
cb_initialize_variables() {
    # Defaults (declared as global)
    declare -g cb_all_mode=false
    declare -g cb_show_functions=false
    declare -g cb_show_aliases=false
    declare -g cb_strict=false
    declare -g cb_debug=false
    declare -g cb_json_output=""
    declare -g cb_single_command=""
    declare -g cb_extra_alias_file=""
    declare -g cb_inherit_aliases=false
}

# -------- Debug function --------
cb_debug_log() {
    if $cb_debug; then
        builtin echo "DEBUG: $*" >&2
    fi
}

# -------- Arg parsing --------
cb_parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all) cb_all_mode=true ;;
            --functions) cb_show_functions=true ;;
            --strict) cb_strict=true ;;
            --debug) cb_debug=true ;;
            --json) shift; cb_json_output="$1" ;;
            -h|--help) cb_show_help; exit 0 ;;
            --version) cb_show_version; exit 0 ;;
            *)
                if [[ -n "$cb_single_command" ]]; then
                    builtin echo "Error: Multiple commands given: '$cb_single_command' and '$1'" >&2
                    exit 1
                fi
                cb_single_command="$1"
                ;;
        esac
        shift
    done
}

# -------- Builtins list --------
cb_initialize_builtins() {
    # Get all shell builtins and keywords, sort them, and remove duplicates
    # Step 1: Get shell builtins (cd, echo, read, etc.)
    local builtins_output
    builtins_output=$(builtin compgen -b)
    
    # Step 2: Get shell keywords (if, for, while, etc.)
    local keywords_output
    keywords_output=$(builtin compgen -k)
    
    # Step 3: Combine both lists, sort alphabetically, and remove duplicates
    local combined_output
    combined_output=$(printf '%s\n%s\n' "$builtins_output" "$keywords_output" | command sort | command uniq)
    
    # Step 4: Read the sorted, unique list into an array
    readarray -t builtin_list <<< "$combined_output"
    declare -ga builtin_list

    # Build a quick lookup associative array for builtins
    declare -gA builtin_lookup
    for _b in "${builtin_list[@]}"; do builtin_lookup["$_b"]=1; done
}

# -------- Whitelist --------
cb_find_config_file() {
    local config_name=".check_builtins"
    local search_paths=(
        "${CHECK_BUILTINS:-}"                    # 1. ENV CHECK_BUILTINS
        "./$config_name"                         # 2. Current directory of execution
        "${BASH_SOURCE[0]%/*}/$config_name"      # 3. Directory location of BASH_SOURCE[0]
        "$HOME/$config_name"                     # 4. $HOME
        "/usr/local/etc/$config_name"            # 5. /usr/local/etc
        "/etc/$config_name"                      # 6. /etc
    )
    
    for path in "${search_paths[@]}"; do
        # Skip empty paths (like when CHECK_BUILTINS is unset)
        [[ -n "$path" && -f "$path" ]] && { builtin echo "$path"; return 0; }
    done
    
    return 1
}

# -------- Configuration loading --------
cb_load_configuration() {
    declare -gA whitelist_commands
    declare -ga critical_additions=()
    declare -ga critical_removals=()

    if config_file=$(cb_find_config_file); then
        if $cb_debug; then builtin echo "DEBUG: Found config file: $config_file" >&2; fi
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ "$line" =~ ^[[:space:]]*$ ]] && continue
            
            # Parse whitelist entries
            if [[ "$line" =~ ^WHITELIST[[:space:]]+([^[:space:]#]+) ]]; then
                whitelist_commands["${BASH_REMATCH[1]}"]=1
            # Parse critical command additions
            elif [[ "$line" =~ ^CRITICAL[[:space:]]+([^[:space:]#]+) ]]; then
                critical_additions+=("${BASH_REMATCH[1]}")
                if $cb_debug; then builtin echo "DEBUG: Adding critical command: ${BASH_REMATCH[1]}" >&2; fi
            # Parse critical command removals
            elif [[ "$line" =~ ^NONCRITICAL[[:space:]]+([^[:space:]#]+) ]]; then
                critical_removals+=("${BASH_REMATCH[1]}")
                if $cb_debug; then builtin echo "DEBUG: Removing critical command: ${BASH_REMATCH[1]}" >&2; fi
            fi
        done < "$config_file"
    else
        if $cb_debug; then builtin echo "DEBUG: No config file found in search paths" >&2; fi
    fi
}

# -------- Critical commands (default list, can be modified by config) --------
# Initialize CRITICAL array with defaults and apply config modifications
cb_initialize_critical_commands() {
    declare -ga CRITICAL=("cd" "rm" "mv" "sudo" "kill" "sh" "bash" "echo" "printf" "ls")

    # Add critical commands from config
    for cmd in "${critical_additions[@]}"; do
        # Check if command is not already in the array
        already_present=false
        for existing in "${CRITICAL[@]}"; do
            if [[ "$existing" == "$cmd" ]]; then
                already_present=true
                break
            fi
        done
        if ! $already_present; then
            CRITICAL+=("$cmd")
            if $cb_debug; then builtin echo "DEBUG: Added '$cmd' to critical commands list" >&2; fi
        fi
    done

    # Remove critical commands from config
    for cmd in "${critical_removals[@]}"; do
        new_critical=()
        for existing in "${CRITICAL[@]}"; do
            if [[ "$existing" != "$cmd" ]]; then
                new_critical+=("$existing")
            else
                if $cb_debug; then builtin echo "DEBUG: Removed '$cmd' from critical commands list" >&2; fi
            fi
        done
        CRITICAL=("${new_critical[@]}")
    done
}

# Source extra alias file if provided
cb_source_extra_alias_file() {
    if [[ -n "$cb_extra_alias_file" && -f "$cb_extra_alias_file" ]]; then
        # shellcheck disable=SC1090
        source "$cb_extra_alias_file" || true
    fi
}

# -------- Detect missing aliases and provide guidance --------
cb_detect_missing_aliases_and_suggest() {
    local cmd="$1"
    
    # If this might be a command with aliases, suggest better detection method
    if [[ "$cmd" == "ls" || "$cmd" == "grep" || "$cmd" == "ll" ]]; then
        if ! alias "$cmd" >/dev/null 2>&1; then
            # No alias detected, but this is a commonly aliased command
            builtin echo "ℹ️  Note: '$cmd' is commonly aliased." >&2
            builtin echo "   To detect aliases from your current shell:" >&2
            builtin echo "   source \"$0\" && cb_export_current_aliases $cmd" >&2
            builtin echo "" >&2
        fi
    fi
}

# -------- Inherit aliases from parent shell --------
cb_inherit_parent_aliases() {
    # If --inherit-aliases flag is set, try to use the export mechanism
    if $cb_inherit_aliases; then
        # Check if we need to re-exec with aliases
        if [[ -z "${CHECK_BUILTINS_ALIAS_FILE:-}" ]]; then
            # We're in the parent shell, need to export aliases and re-exec
            cb_debug_log "Re-executing with exported aliases"
            
            # The issue is that when this script is executed (not sourced), 
            # it's already in a child shell without the parent's aliases.
            # We need to tell the user to use the proper invocation method.
            builtin echo "Error: --inherit-aliases requires sourcing the script from your shell." >&2
            builtin echo "Use one of these methods instead:" >&2
            builtin echo "  bash -c 'source \"$0\" && cb_export_current_aliases $*'" >&2
            builtin echo "  # Or define your aliases in the same context:" >&2
            builtin echo "  bash -c 'alias your_alias=\"...\"; source \"$0\"; cb_export_current_aliases $*'" >&2
            exit 2
        fi
        # If we reach here, we're in the child process with aliases loaded
        return 0
    fi
    
    # Try to inherit aliases from the parent shell environment
    # This helps detect aliases that are active in the calling shell
    if [[ -n "${BASH_ALIASES_EXPORT:-}" ]]; then
        # If parent shell exported aliases, source them
        eval "$BASH_ALIASES_EXPORT" 2>/dev/null || true
    fi
}

# -------- check_command Function --------
cb_check_command() {
    local cmd="$1"
    cb_debug_log "check_command called with '$cmd'"
    local status=4
    local info=""

    # Determine alias/function/builtin/extern layering via type -a (no side-effects)
    cb_debug_log "Getting type output for '$cmd'"
    local type_output
    if type_output=$(type -a "$cmd" 2>/dev/null); then
        cb_debug_log "Got type output: $type_output"
        # Collect lines
        local has_alias="" has_function="" has_builtin="" has_external="" external_paths=() alias_def="" has_keyword=""
        while IFS= read -r line; do
            cb_debug_log "Processing line: '$line'"
            case $line in
                *' is aliased to '* )
                    has_alias=1
                    alias_def=${line#* is aliased to }
                    # Trim leading quote/backtick
                    alias_def=${alias_def#\`}; alias_def=${alias_def#\'}; alias_def=${alias_def#\"}
                    # Trim trailing quote/backtick
                    alias_def=${alias_def%\'}; alias_def=${alias_def%\`}; alias_def=${alias_def%\"}
                    ;;
                *' is a function') has_function=1 ;;
                *' is a shell builtin') has_builtin=1 ;;
                *' is a shell keyword') has_keyword=1 ;;
                *' is /'*)
                    has_external=1
                    # Collect ALL external paths
                    external_paths+=("${line#* is }")
                    ;;
            esac
        done <<< "$type_output"
        cb_debug_log "Finished processing lines. has_external='$has_external' external_paths=(${external_paths[*]})"

        # Build the detection chain showing all found items
        local detection_chain=""
        local chain_parts=()
        
        # Collect all detected items in order of precedence
        if [[ -n "$has_alias" ]]; then
            chain_parts+=("alias → $alias_def")
        fi
        if [[ -n "$has_function" ]]; then
            chain_parts+=("function")
        fi
        if [[ -n "$has_builtin" ]]; then
            chain_parts+=("builtin")
        fi
        if [[ -n "$has_keyword" ]]; then
            chain_parts+=("keyword")
        fi
        if [[ -n "$has_external" ]]; then
            # Build external chain showing all paths with their PATH positions
            cb_debug_log "Processing external commands for chain"
            IFS=: read -ra dirs <<<"$PATH"
            local external_chain_parts=()
            
            for external_path in "${external_paths[@]}"; do
                # Find PATH position for this external path
                local idx=1
                local found_position=""
                for d in "${dirs[@]}"; do
                    if [[ "$d/$cmd" == "$external_path" ]]; then
                        found_position="PATH position $idx"
                        cb_debug_log "Found executable at position $idx: $external_path"
                        break
                    fi
                    ((idx++))
                done
                
                if [[ -n "$found_position" ]]; then
                    external_chain_parts+=("external → $external_path ($found_position)")
                else
                    external_chain_parts+=("external → $external_path")
                fi
            done
            
            # Add all external parts to the main chain
            chain_parts+=("${external_chain_parts[@]}")
        fi
        
        # Join the chain with " | " separator
        if [[ ${#chain_parts[@]} -gt 0 ]]; then
            detection_chain=$(IFS=" | "; echo "${chain_parts[*]}")
        fi

        # Determine status and primary info based on bash precedence (alias > function > builtin/keyword > external)
        if [[ -n "$has_alias" ]]; then
            if [[ -n "${whitelist_commands[$cmd]:-}" ]]; then
                status=5; info="whitelisted alias override | $detection_chain"
            else
                status=2; info="alias override | $detection_chain"
            fi
        elif [[ -n "$has_function" ]]; then
            if [[ -n "${whitelist_commands[$cmd]:-}" ]]; then
                status=5; info="whitelisted function override | $detection_chain"
            else
                status=1; info="function override | $detection_chain"
            fi
        elif [[ -n "$has_builtin" ]]; then
            status=0; info="builtin | $detection_chain"
        elif [[ -n "$has_keyword" ]]; then
            status=0; info="keyword | $detection_chain"
        elif [[ -n "$has_external" ]]; then
            status=3; info="external command | $detection_chain"
            cb_debug_log "Set status=$status info='$info'"
        else
            status=4; info="unknown"
        fi
    else
        status=4; info="unknown"
    fi

    builtin echo "$status|$cmd|$info"
    cb_debug_log "About to return with status $status"
    return $status
}

# -------- Colorization --------
cb_colorize_status() {
    local code="$1"
    case "$code" in
        0) builtin echo -e "$CHECKMARK" ;;
        1|2) builtin echo -e "${BOLD}${CROSS}${RESET}" ;;
        3) builtin echo -e "${BOLD}${WARN}${RESET}" ;;
        4) builtin echo -e "${BOLD}${CROSS}${RESET}" ;;
        5) builtin echo -e "${YELLOW}✓${RESET}" ;;
    esac
}

# -------- Table output --------
cb_print_table_header() {
    builtin printf "%-20s %-6s %s\n" "COMMAND" "STATUS" "INFO"
    builtin printf "%-20s %-6s %s\n" "-------" "------" "----"
}

# -------- Table output --------
cb_print_table_row() {
    local code="$1"
    local cmd="$2"
    local info="$3"
    local symbol
    symbol=$(cb_colorize_status "$code")
    builtin printf "%-20s %-6s %s\n" "$cmd" "$symbol" "$info"
}

# -------- Single command mode --------
cb_run_single_command_mode() {
    cb_debug_log "single_command='$cb_single_command' all_mode=$cb_all_mode"
    if [[ -n "$cb_single_command" ]]; then
        cb_debug_log "Entering single command mode"
        
        # First check if we should suggest better alias detection
        if [[ $cb_inherit_aliases == false ]]; then
            cb_detect_missing_aliases_and_suggest "$cb_single_command"
        fi
        
        result=$(cb_check_command "$cb_single_command") || true
        cb_debug_log "Debug result: $result"
        IFS="|" read -r code cmd info <<<"$result"
        cb_debug_log "Debug parsed: code=$code cmd=$cmd info=$info"
        cb_print_table_header
        cb_print_table_row "$code" "$cmd" "$info"
        return 0
    fi
    return 1  # Not single command mode
}

# -------- All mode --------
cb_run_all_mode() {
    if $cb_all_mode; then
        worst=0
        declare -a json_array
        declare -a checked_commands
        
        cb_print_table_header
        
        # Check all builtins
        for b in "${builtin_list[@]}"; do
            result=$(cb_check_command "$b") || true
            IFS="|" read -r code cmd info <<<"$result"
            cb_print_table_row "$code" "$cmd" "$info"
            (( code > worst )) && worst=$code
            if [[ -n "$cb_json_output" ]]; then
                json_array+=("{\"command\":\"$cmd\",\"status\":$code,\"info\":\"${info//\"/\\\"}\"}")
            fi
            checked_commands+=("$cmd")
        done

        builtin echo -e "\nCritical commands audit:"
        cb_print_table_header
        for c in "${CRITICAL[@]}"; do
            result=$(cb_check_command "$c") || true
            IFS="|" read -r code cmd info <<<"$result"
            cb_print_table_row "$code" "$cmd" "$info"
            (( code > worst )) && worst=$code
        done

        if $cb_show_functions; then
            builtin echo -e "\nUser-defined functions:"
            builtin declare -F | awk '{print $3}'
        fi

        if [[ -n "$cb_json_output" ]]; then
            builtin printf '[%s]\n' "$(IFS=,; builtin echo "${json_array[*]}")" >"$cb_json_output"
            builtin echo "JSON report written to $cb_json_output"
        fi

        if $cb_strict; then
            builtin echo "Worst status found: $worst"
            return 0
        fi
        return 0
    fi
    return 1  # Not all mode
}

# -------- Main function --------
cb_main() {
    # Initialize variables first (needed for debug_log)
    cb_initialize_variables
    cb_parse_arguments "$@"
    
    # Load configuration and setup
    cb_load_exported_aliases      # Load aliases from parent shell if available
    cb_inherit_parent_aliases "$@"  # Try to inherit aliases from parent shell
    cb_initialize_builtins
    cb_load_configuration
    cb_initialize_critical_commands
    cb_source_extra_alias_file

    # Run appropriate mode
    cb_run_single_command_mode || cb_run_all_mode || {
        # If we get here, no valid arguments were provided
        cb_show_help
        exit 2  # Standard exit code for improper usage
    }
    
    # Always exit 0 for successful execution (status numbers are reported in output)
    exit 0
}

# -------- Export current aliases function (for sourced mode) --------
#
#  WARNING: cb_export_current_aliases() uses 'exec' and should NEVER be called when
#           the script is executed directly (./check_builtin.sh). It must only be
#           used when the script is sourced into your shell.
#
cb_export_current_aliases() {
    # SAFETY CHECK: This function should only be called when the script is sourced
    # It uses 'exec' which replaces the current shell process
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        builtin echo "ERROR: cb_export_current_aliases() cannot be called when script is executed directly." >&2
        builtin echo "This function uses 'exec' which would replace your current shell process." >&2
        builtin echo "" >&2
        builtin echo "This function should only be used when the script is sourced:" >&2
        builtin echo "  source check_builtin.sh" >&2
        builtin echo "  cb_export_current_aliases [command]" >&2
        builtin echo "" >&2
        builtin echo "Or use the recommended method:" >&2
        builtin echo "  bash -c 'alias cmd=\"...\"; source check_builtin.sh; cb_export_current_aliases cmd'" >&2
        return 1
    fi
    
    # SAFETY CHECK: Require at least one argument
    if [[ $# -eq 0 ]]; then
        builtin echo "ERROR: cb_export_current_aliases() requires at least one argument (command to check)." >&2
        builtin echo "" >&2
        builtin echo "Usage:" >&2
        builtin echo "  cb_export_current_aliases [command]" >&2
        builtin echo "  cb_export_current_aliases --debug [command]" >&2
        builtin echo "" >&2
        builtin echo "Examples:" >&2
        builtin echo "  cb_export_current_aliases ls" >&2
        builtin echo "  cb_export_current_aliases --debug ls" >&2
        return 1
    fi
    
    # This function will be called from the parent shell to export its aliases
    # It creates a temporary file with alias definitions that can be sourced
    local temp_alias_file
    temp_alias_file=$(mktemp)
    
    # Export all current aliases to the temp file
    # Use 'builtin alias' to ensure we get the shell builtin, not any alias of 'alias'
    builtin alias > "$temp_alias_file" 2>/dev/null || true
    
    # Debug: show what was captured
    if [[ "${1:-}" == "--debug" ]]; then
        echo "DEBUG: Captured aliases:" >&2
        cat "$temp_alias_file" >&2
        echo "DEBUG: Number of aliases: $(wc -l < "$temp_alias_file")" >&2
    fi
    
    # Export the temp file path so the child process can find it
    export CHECK_BUILTINS_ALIAS_FILE="$temp_alias_file"
    
    # Clean up function
    trap 'rm -f "$temp_alias_file"' EXIT
    
    # Execute the script with inherited aliases
    # Use BASH_SOURCE[0] to get the script path when sourced
    #local script_path="${BASH_SOURCE[0]}"
    #exec "$script_path" "$@"
    cb_main "$@"
}


# Only call cb_main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cb_main "$@"
fi
