function code_cleanup() {
    local paths=(
        "$HOME/.vscode"
        "$HOME/.antigravity"
        "$HOME/.config/Code/Cache"
        "$HOME/.config/Code/Code Cache"
        "$HOME/.config/Code/User/globalStorage"
        "$HOME/.config/Antigravity IDE/Cache"
        "$HOME/.config/Antigravity IDE/Code Cache"
        "$HOME/.config/Antigravity IDE/User/globalStorage"
    )
    for p in "${paths[@]}"; do
        [[ -e "$p" ]] && rm -rf "$p"
    done
}

function code_install_extensions() {
    local installed
    installed="$(code --list-extensions 2>/dev/null)"
    for ext in "$@"; do
        if ! echo "$installed" | grep -qiFx "$ext"; then
            code --install-extension "$ext"
        fi
    done
}

function code_install_extensions_from_txt() {
    local path="$1"
    if [[ -f "$path" ]]; then
        local extensions=()
        while IFS= read -r line || [[ -n "$line" ]]; do
            line="${line%%#*}"
            line="$(echo "$line" | xargs)"
            [[ -n "$line" ]] && extensions+=("$line")
        done < "$path"
        code_install_extensions "${extensions[@]}"
    fi
}

function code_wsl() {
    local folder_path="${1:-.}"
    if [[ "$folder_path" == "~"* ]]; then
        folder_path="${folder_path/#\~/$HOME}"
    fi
    if type wslpath &>/dev/null && [[ "$folder_path" != \\\\* && "$folder_path" != //* && ! "$folder_path" =~ ^[a-zA-Z]: ]]; then
        folder_path="$(wslpath -w "$folder_path" 2>/dev/null || echo "$folder_path")"
    fi
    if [[ "$folder_path" == //wsl* ]]; then
        folder_path="\\\\${folder_path#//}"
        folder_path="${folder_path//\//\\}"
    fi
    local re_root='^\\\\wsl(\.localhost|\$)\\[^\\]+$'
    if [[ "$folder_path" =~ $re_root ]]; then
        folder_path="${folder_path}\\"
    fi
    local re='^\\\\wsl(\.localhost|\$)\\([^\\]+)\\(.*)$'
    if [[ "$folder_path" =~ $re ]]; then
        local distro_name="${BASH_REMATCH[2]}"
        local linux_path="/${BASH_REMATCH[3]//\\//}"
        code --remote "wsl+$distro_name" "$linux_path"
    else
        code "$folder_path"
    fi
}
