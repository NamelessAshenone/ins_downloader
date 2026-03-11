# Shell helpers for Instagram downloads (macOS / Linux)
# Mirrors Windows Ins-Alias / Ins-Download / Ins-SetDir behavior
#
# Source this file in your shell config (e.g. ~/.zshrc or ~/.bashrc):
#   source "/path/to/ins_tools.sh"

# Guard: warn if executed directly instead of sourced
(return 0 2>/dev/null) || {
    echo "WARNING: This script should be sourced, not executed directly." >&2
    echo "Run:  source \"$0\"" >&2
    echo "Or add that line to your ~/.zshrc / ~/.bashrc" >&2
    exit 1
}

# Configurable defaults
: "${INS_ALIAS_FILE:=$HOME/.ins_aliases}"
: "${INS_CHROME_PROFILE:=Default}"
INS_CONFIG_FILE="$HOME/.ins_download_dir"
INS_DEFAULT_SAFE_DIR="$HOME/Pictures/ins_pictures"

# Ensure Python user bin directory is in PATH (pip --user installs go there)
if ! command -v gallery-dl &>/dev/null; then
    _py_user_base=$(python3 -m site --user-base 2>/dev/null || python -m site --user-base 2>/dev/null || true)
    if [[ -n "$_py_user_base" && -d "$_py_user_base/bin" ]]; then
        case ":$PATH:" in
            *":$_py_user_base/bin:"*) ;;
            *) export PATH="$_py_user_base/bin:$PATH" ;;
        esac
    fi
    unset _py_user_base
fi

# Download directory: env var → persisted config file → not yet configured
INS_DOWNLOAD_DIR_CONFIGURED=false
if [[ -n "${INS_DOWNLOAD_DIR:-}" ]]; then
    INS_DOWNLOAD_DIR_CONFIGURED=true
elif [[ -f "$INS_CONFIG_FILE" ]]; then
    _ins_saved_dir=$(head -1 "$INS_CONFIG_FILE" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -n "$_ins_saved_dir" ]]; then
        INS_DOWNLOAD_DIR="$_ins_saved_dir"
        INS_DOWNLOAD_DIR_CONFIGURED=true
    fi
    unset _ins_saved_dir
fi

ins_setdir() {
    if [[ $# -eq 0 || -z "$1" ]]; then
        if [[ "$INS_DOWNLOAD_DIR_CONFIGURED" == true ]]; then
            echo "Current download directory: $INS_DOWNLOAD_DIR"
        else
            echo "No download directory configured yet."
        fi
        echo "Usage: ins_setdir <path>"
        return
    fi
    local dir="$1"
    dir="${dir/#\~/$HOME}"
    mkdir -p "$dir" 2>/dev/null
    if [[ -d "$dir" ]]; then
        dir="$(cd "$dir" && pwd)"
    fi
    INS_DOWNLOAD_DIR="$dir"
    INS_DOWNLOAD_DIR_CONFIGURED=true
    echo "$dir" > "$INS_CONFIG_FILE"
    echo "Download directory set to: $dir"
}

ins_alias() {
    local action="${1:-}"
    local alias_name="${2:-}"
    local real_id="${3:-}"

    # Create alias file if missing
    [[ -f "$INS_ALIAS_FILE" ]] || touch "$INS_ALIAS_FILE"

    case "$action" in
        add|modify)
            if [[ -z "$alias_name" || -z "$real_id" ]]; then
                echo "Usage: ins_alias add <alias> <real_username>"
                return
            fi
            # unique constraint: one real user → one alias
            local existing_alias
            existing_alias=$(awk -v user="$real_id" '$2 == user { print $1 }' "$INS_ALIAS_FILE")
            if [[ -n "$existing_alias" && "$existing_alias" != "$alias_name" ]]; then
                printf "User @%s already has alias [%s]. Overwrite with [%s]? (y/n) " "$real_id" "$existing_alias" "$alias_name"
                local resp
                read -r resp
                if [[ "$resp" != "y" && "$resp" != "Y" ]]; then
                    echo "Cancelled."
                    return
                fi
                # Remove old alias for this real user
                local tmp
                tmp=$(mktemp)
                awk -v user="$real_id" '$2 != user' "$INS_ALIAS_FILE" > "$tmp" && mv "$tmp" "$INS_ALIAS_FILE"
            fi
            # Remove existing entry for this alias name, then append
            local tmp2
            tmp2=$(mktemp)
            awk -v a="$alias_name" '$1 != a' "$INS_ALIAS_FILE" > "$tmp2" && mv "$tmp2" "$INS_ALIAS_FILE"
            echo "$alias_name $real_id" >> "$INS_ALIAS_FILE"
            echo "Saved: $alias_name -> @$real_id"
            ;;
        remove|delete)
            if [[ -z "$alias_name" ]]; then
                echo "Usage: ins_alias delete <alias>"
                return
            fi
            local tmp3
            tmp3=$(mktemp)
            awk -v a="$alias_name" '$1 != a' "$INS_ALIAS_FILE" > "$tmp3" && mv "$tmp3" "$INS_ALIAS_FILE"
            echo "Deleted alias $alias_name"
            ;;
        list|show)
            echo "Aliases in $INS_ALIAS_FILE"
            sort "$INS_ALIAS_FILE" | while IFS=' ' read -r a u; do
                [[ -n "$a" && -n "$u" ]] && printf "%-15s %s\n" "$a" "$u"
            done
            ;;
        search|find)
            if [[ -z "$alias_name" ]]; then
                echo "Usage: ins_alias search <keyword>"
                return
            fi
            echo "Searching: $alias_name"
            grep -i "$alias_name" "$INS_ALIAS_FILE" | while IFS=' ' read -r a u; do
                [[ -n "$a" && -n "$u" ]] && printf "%-15s %s\n" "$a" "$u"
            done
            ;;
        *)
            echo "Usage: ins_alias <add|modify|remove|delete|list|show|search|find> [alias] [real_username]"
            ;;
    esac
}

ins_download() {
    local target="" directory="" top="" limit="" limit_set=false only=false
    local include="" exclude="" show_help=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help|-Help)
                show_help=true; shift ;;
            -t|--top|-Top)
                top="$2"; shift 2 ;;
            -l|--limit|-Limit)
                limit_set=true
                # Check if next arg is a number (optional value)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                    limit="$2"; shift 2
                else
                    limit=""; shift
                fi
                ;;
            -o|--only|-Only)
                only=true; shift ;;
            -i|--include|-Include)
                include="$2"; shift 2 ;;
            -e|--exclude|-Exclude)
                exclude="$2"; shift 2 ;;
            -d|--dir|-Directory)
                directory="$2"; shift 2 ;;
            -*)
                echo "Unknown option: $1"; return 1 ;;
            *)
                if [[ -z "$target" ]]; then
                    target="$1"
                else
                    echo "Unexpected argument: $1"; return 1
                fi
                shift ;;
        esac
    done

    if $show_help || [[ -z "$target" ]]; then
        echo "Usage: ins_download <URL|alias|username> [-t N] [-l [N]] [-o] [-i spec] [-e spec] [-d dir]"
        echo "  -t/--top N       : URL and User mode -> first N media per post/carousel"
        echo "  -l/--limit [N]   : URL mode -> per-post cap (default 5); user/alias -> total cap globally (default 20)"
        echo "  -o/--only        : URL mode, download only current media (img_index)"
        echo "  -i/--include spec: ranges like 1,3 or 2-4 (URL mode)"
        echo "  -e/--exclude spec: ranges like 1,3 or 2-4 (URL mode)"
        echo "  -d/--dir dir     : custom output directory for this download"
        echo "  -h/--help        : show this help"
        return
    fi

    # Determine mode and resolve alias
    local mode real_user="" current_alias=""

    if [[ "$target" == http* ]]; then
        mode="url"
        # Remove query string
        target="${target%%\?*}"
    else
        mode="user"
        local alias_lookup
        alias_lookup=$(awk -v a="$target" '$1 == a { print $2 }' "$INS_ALIAS_FILE" 2>/dev/null)
        if [[ -n "$alias_lookup" ]]; then
            current_alias="$target"
            real_user="$alias_lookup"
        else
            real_user="$target"
        fi
        target="https://www.instagram.com/$real_user/"
    fi

    # First-time directory prompt when no -d specified and no default configured
    if [[ -z "$directory" && "$INS_DOWNLOAD_DIR_CONFIGURED" != true ]]; then
        echo "No default download directory has been configured."
        printf "Enter a download directory path (or press Enter to use default: %s): " "$INS_DEFAULT_SAFE_DIR"
        local user_dir
        read -r user_dir
        if [[ -z "$user_dir" ]]; then
            INS_DOWNLOAD_DIR="$INS_DEFAULT_SAFE_DIR"
            echo "Using default directory: $INS_DEFAULT_SAFE_DIR"
        else
            user_dir="${user_dir/#\~/$HOME}"
            mkdir -p "$user_dir" 2>/dev/null
            if [[ -d "$user_dir" ]]; then
                user_dir="$(cd "$user_dir" && pwd)"
            fi
            INS_DOWNLOAD_DIR="$user_dir"
            echo "Download directory set to: $user_dir"
        fi
        INS_DOWNLOAD_DIR_CONFIGURED=true
        echo "$INS_DOWNLOAD_DIR" > "$INS_CONFIG_FILE"
    fi

    local folder_name="${real_user:-unknown}"
    local target_dir
    if [[ -n "$directory" ]]; then
        target_dir="$directory"
    elif [[ -n "$current_alias" ]]; then
        target_dir="$INS_DOWNLOAD_DIR/$current_alias"
    else
        target_dir="$INS_DOWNLOAD_DIR/$folder_name"
    fi
    mkdir -p "$target_dir"

    local filename_prefix
    if [[ -n "$current_alias" ]]; then
        filename_prefix="$current_alias"
    else
        filename_prefix="{username}"
    fi

    local gdl_args=(
        --cookies-from-browser "chrome:${INS_CHROME_PROFILE}"
        -d "$target_dir"
        -o "directory=[]"
        -o "filename=${filename_prefix}_{date:%Y%m%d_%H%M}_{num}.{extension}"
        --retries 10
        -o "http.timeout=60"
        --sleep 1-5
        -o "write-info-json=true"
        -o "download.clobber=numbered"
    )

    if [[ "$mode" == "url" ]]; then
        if $only; then
            local img_idx
            img_idx=$(echo "$target" | grep -o 'img_index=[0-9]*' | grep -o '[0-9]*')
            [[ -z "$img_idx" ]] && img_idx=1
            gdl_args+=(--range "$img_idx")
        fi
        [[ -n "$top" ]] && gdl_args+=(--range "1-$top")
        [[ -n "$include" ]] && gdl_args+=(--range "$include")
        if [[ -n "$exclude" ]]; then
            local range_start range_end
            range_start=$(echo "$exclude" | sed -n 's/^\([0-9]*\)-\([0-9]*\)$/\1/p')
            range_end=$(echo "$exclude" | sed -n 's/^\([0-9]*\)-\([0-9]*\)$/\2/p')
            if [[ -n "$range_start" && -n "$range_end" ]]; then
                gdl_args+=(--filter "num < $range_start or num > $range_end")
            else
                gdl_args+=(--filter "num != $exclude")
            fi
        fi
        if $limit_set; then
            local effective="${limit:-5}"
            gdl_args+=(--filter "num <= $effective")
        fi
    else
        local effective_limit
        if $limit_set; then
            effective_limit="${limit:-20}"
        else
            effective_limit=20
        fi
        
        # In user mode, we want a total cap, mapping Limit to --range
        gdl_args+=(--range "1-$effective_limit")
        
        # -t/--top restricts the number of media within carousels per post
        [[ -n "$top" ]] && gdl_args+=(--filter "num <= $top")
    fi

    local log_file
    log_file=$(mktemp)
    echo "Downloading to $target_dir"
    gallery-dl "${gdl_args[@]}" "$target" > "$log_file" 2>&1
    local exit_code=$?
    cat "$log_file"

    if grep -qE 'HTTP error (429|403)' "$log_file" 2>/dev/null; then
        echo "Detected 429/403. Backing off for 120 seconds..."
        sleep 120
    fi

    rm -f "$log_file"

    if [[ $exit_code -eq 0 ]]; then
        echo "Done"
    else
        echo "gallery-dl exited with code $exit_code"
    fi
}
