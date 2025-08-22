#!/usr/bin/env bash
set -euo pipefail
shopt -s expand_aliases

# Optionally load bashrc files (to capture user aliases) unless disabled
if [[ -z "${CHECK_BUILTINS_NO_RC:-}" ]]; then
    for _rc in /etc/bash.bashrc ~/.bashrc; do
        if [[ -f "$_rc" ]]; then
            # Temporarily relax nounset and ensure PS1 defined to avoid errors
            set +u
            : "${PS1:=}"  # define PS1 if unset
            # shellcheck disable=SC1090
            source "$_rc" || true
            set -u
        fi
    done
fi

# -------- Colors --------
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BOLD="\033[1m"
RESET="\033[0m"
CHECKMARK="${GREEN}✔${RESET}"
CROSS="${RED}❌${RESET}"
WARN="${YELLOW}⚠${RESET}"

# -------- Critical commands --------
CRITICAL=("cd" "rm" "mv" "sudo" "kill" "sh" "bash" "echo" "printf")

# -------- Help --------
show_help() {
    command cat <<EOF
Usage:
  check_builtins.sh [command]       # check a single command
  check_builtins.sh -a|--all        # list all builtins and overrides
    Options:
      --functions                  # show user-defined functions
      --aliases                    # show user-defined aliases
      --strict                     # exit non-zero if any override found
      --debug                      # enable debug output
      --json <file>                # export results to JSON
      --alias-file <file>          # source additional alias file
  check_builtins.sh -h|--help      # show this help

Exit codes:
  Single command mode:
    0 = builtin
    1 = function override  
    2 = alias override
    3 = external command in PATH
    4 = unknown
    5 = whitelisted override
  All mode:
    0 = success (no issues or --strict not used)
    1-5 = worst issue found (only with --strict)
  General:
    2 = improper usage
EOF
}

# -------- Defaults --------
all_mode=false
show_functions=false
show_aliases=false
strict=false
debug=false
json_output=""
single_command=""
extra_alias_file=""

# -------- Arg parsing --------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--all) all_mode=true ;;
        --functions) show_functions=true ;;
        --aliases) show_aliases=true ;;
        --strict) strict=true ;;
        --debug) debug=true ;;
    --json) shift; json_output="$1" ;;
    --alias-file) shift; extra_alias_file="$1" ;;
        -h|--help) show_help; exit 0 ;;
        *)
            if [[ -n "$single_command" ]]; then
                builtin echo "Error: Multiple commands given: '$single_command' and '$1'" >&2
                exit 1
            fi
            single_command="$1"
            ;;
    esac
    shift
done

# -------- Builtins list --------
readarray -t builtin_list < <(builtin help | awk '/^ [a-z][a-zA-Z_]*[[:space:]]/ {print $1}' | grep -v '^job_spec$' | sort | uniq)

# Build a quick lookup associative array for builtins
declare -A builtin_lookup
for _b in "${builtin_list[@]}"; do builtin_lookup["$_b"]=1; done

# -------- Whitelist --------
declare -A whitelist_commands
config_file="${BASH_SOURCE[0]%/*}/.check_builtins"
if [[ -f "$config_file" ]]; then
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        
        # Parse whitelist entries
        if [[ "$line" =~ ^whitelist[[:space:]]+([^[:space:]#]+) ]]; then
            whitelist_commands["${BASH_REMATCH[1]}"]=1
        fi
    done < "$config_file"
fi

# Source extra alias file if provided
if [[ -n "$extra_alias_file" && -f "$extra_alias_file" ]]; then
    # shellcheck disable=SC1090
    source "$extra_alias_file" || true
fi

# -------- Functions --------
debug_log() {
    if $debug; then
        builtin echo "DEBUG: $*" >&2
    fi
}

check_command() {
    local cmd="$1"
    debug_log "check_command called with '$cmd'"
    local status=4
    local info=""
    local path_info=""

    # Determine alias/function/builtin/extern layering via type -a (no side-effects)
    debug_log "Getting type output for '$cmd'"
    local type_output
    if type_output=$(type -a "$cmd" 2>/dev/null); then
        debug_log "Got type output"
        # Collect lines
        local has_alias="" has_function="" has_builtin="" has_external="" external_path="" alias_def="" has_keyword=""
        while IFS= read -r line; do
            debug_log "Processing line: '$line'"
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
                    # Only capture the first external path (which is the one that would be executed)
                    if [[ -z "$external_path" ]]; then
                        external_path=${line#* is }
                    fi
                    ;;
            esac
        done <<< "$type_output"
        debug_log "Finished processing lines. has_external='$has_external' external_path='$external_path'"

        # Decide precedence (alias > function > builtin/keyword > external)
        if [[ -n "$has_alias" ]]; then
            if [[ -n "${builtin_lookup[$cmd]:-}" ]]; then
                if [[ -n "${whitelist_commands[$cmd]:-}" ]]; then
                    status=5; info="whitelisted alias → $alias_def (overrides builtin)"
                else
                    status=2; info="alias → $alias_def (overrides builtin)"
                fi
            elif [[ -n "$has_external" ]]; then
                if [[ -n "${whitelist_commands[$cmd]:-}" ]]; then
                    status=5; info="whitelisted alias → $alias_def (overrides $external_path)"
                else
                    status=2; info="alias → $alias_def (overrides $external_path)"
                fi
            else
                if [[ -n "${whitelist_commands[$cmd]:-}" ]]; then
                    status=5; info="whitelisted alias → $alias_def"
                else
                    status=2; info="alias → $alias_def"
                fi
            fi
        elif [[ -n "$has_function" ]]; then
            if [[ -n "${builtin_lookup[$cmd]:-}" ]]; then
                if [[ -n "${whitelist_commands[$cmd]:-}" ]]; then
                    status=5; info="whitelisted function (overrides builtin)"
                else
                    status=1; info="function (overrides builtin)"
                fi
            elif [[ -n "$has_external" ]]; then
                if [[ -n "${whitelist_commands[$cmd]:-}" ]]; then
                    status=5; info="whitelisted function (overrides $external_path)"
                else
                    status=1; info="function (overrides $external_path)"
                fi
            else
                status=1; info="function"
            fi
        elif [[ -n "$has_builtin" ]]; then
            status=0; info="builtin"
        elif [[ -n "$has_keyword" ]]; then
            status=0; info="keyword"
        elif [[ -n "$has_external" ]]; then
            debug_log "Processing external command"
            # external only
            IFS=: read -ra dirs <<<"$PATH"
            local idx=1
            for d in "${dirs[@]}"; do
                if [[ -x "$d/$cmd" ]]; then
                    path_info="found in $d (PATH position $idx)"
                    debug_log "Found executable at position $idx: $d/$cmd"
                    break
                fi
                ((idx++))
            done
            status=3; info="external → $external_path ($path_info)"
            debug_log "Set status=$status info='$info'"
        else
            status=4; info="unknown"
        fi
    else
        status=4; info="unknown"
    fi

    builtin echo "$status|$cmd|$info"
    debug_log "About to return with status $status"
    return $status
}

colorize_status() {
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
print_table_header() {
    builtin printf "%-20s %-6s %s\n" "COMMAND" "STATUS" "INFO"
    builtin printf "%-20s %-6s %s\n" "-------" "------" "----"
}

print_table_row() {
    local code="$1"
    local cmd="$2"
    local info="$3"
    local symbol
    symbol=$(colorize_status "$code")
    builtin printf "%-20s %-6s %s\n" "$cmd" "$symbol" "$info"
}

# -------- Single command mode --------
debug_log "single_command='$single_command' all_mode=$all_mode"
if [[ -n "$single_command" ]]; then
    debug_log "Entering single command mode"
    result=$(check_command "$single_command") || true
    debug_log "Debug result: $result"
    IFS="|" read -r code cmd info <<<"$result"
    debug_log "Debug parsed: code=$code cmd=$cmd info=$info"
    print_table_header
    print_table_row "$code" "$cmd" "$info"
    exit $code
fi

# -------- All mode --------
if $all_mode; then
    worst=0
    declare -a json_array
    declare -a checked_commands
    
    print_table_header
    
    # Check all builtins
    for b in "${builtin_list[@]}"; do
        result=$(check_command "$b") || true
        IFS="|" read -r code cmd info <<<"$result"
        print_table_row "$code" "$cmd" "$info"
        (( code > worst )) && worst=$code
        if [[ -n "$json_output" ]]; then
            json_array+=("{\"command\":\"$cmd\",\"status\":$code,\"info\":\"${info//\"/\\\"}\"}")
        fi
        checked_commands+=("$cmd")
    done

    # If --aliases flag is used, also enumerate every alias (including plain ones)
    if $show_aliases; then
        builtin echo -e "\nActive aliases:"
        print_table_header
        while IFS= read -r alias_line; do
            [[ $alias_line =~ ^alias[[:space:]]+([^=]+)= ]] || continue
            alias_name="${BASH_REMATCH[1]}"
            result=$(check_command "$alias_name") || true
            IFS="|" read -r code cmd info <<<"$result"
            print_table_row "$code" "$cmd" "$info"
            (( code > worst )) && worst=$code
        done < <(alias 2>/dev/null || true)
    fi

    builtin echo -e "\nCritical commands audit:"
    print_table_header
    for c in "${CRITICAL[@]}"; do
        result=$(check_command "$c") || true
        IFS="|" read -r code cmd info <<<"$result"
        print_table_row "$code" "$cmd" "$info"
    done

    if $show_functions; then
        builtin echo -e "\nUser-defined functions:"
        builtin declare -F | awk '{print $3}'
    fi

    if [[ -n "$json_output" ]]; then
        builtin printf '[%s]\n' "$(IFS=,; builtin echo "${json_array[*]}")" >"$json_output"
        builtin echo "JSON report written to $json_output"
    fi

    if $strict; then
        exit $worst
    fi
    exit 0
fi

# If we get here, no valid arguments were provided
show_help
exit 2  # Standard exit code for improper usage