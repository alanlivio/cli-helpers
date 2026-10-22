function _wsl_auto_open() {
    local executable="$1"
    shift
    if [[ "$1" == -* ]]; then
        "$executable" "$@"
        return $?
    fi
    local folder_path="${1:-.}"
    local is_file=false
    if [[ -f "$folder_path" ]]; then
        is_file=true
    fi
    if [[ "$folder_path" == "~"* ]]; then
        folder_path="${folder_path/#\~/$HOME}"
    fi
    if type wslpath &>/dev/null && [[ "$folder_path" != \\\\* && "$folder_path" != //* && ! "$folder_path" =~ ^[a-zA-Z]: ]]; then
        folder_path="$(wslpath -a -w "$folder_path" 2>/dev/null || echo "$folder_path")"
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
        if [[ "$is_file" == true ]]; then
            "$executable" --file-uri "vscode-remote://wsl+$distro_name$linux_path" "${@:2}"
        else
            "$executable" --folder-uri "vscode-remote://wsl+$distro_name$linux_path" "${@:2}"
        fi
    else
        "$executable" "$folder_path" "${@:2}"
    fi
}

# -- code --

function _code_server_executable() {
    local exe
    exe=$(find ~/.vscode-server/bin -name code-server -type f 2>/dev/null | head -n 1)
    echo "${exe:-code}"
}

function code_install_extensions() {
    local executable
    executable="$(_code_server_executable)"
    local installed
    installed="$("$executable" --list-extensions 2>/dev/null)"
    for ext in "$@"; do
        if ! echo "$installed" | grep -qiFx "$ext"; then
            "$executable" --install-extension "$ext" 2>/dev/null || true
        fi
    done
}

function code_install_extensions_from_txt() {
    local path="$1"
    if [[ -z "$path" || ! -f "$path" ]]; then
        return 1
    fi
    local extensions=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="$(echo "$line" | xargs)"
        [[ -n "$line" ]] && extensions+=("$line")
    done <"$path"
    code_install_extensions "${extensions[@]}"
}

function _code_client_executable() {
    local found
    found=$(find "/mnt/c/Program Files/Microsoft VS Code/bin" "/mnt/c/Program Files (x86)/Microsoft VS Code/bin" "$LOCALAPPDATA/Programs/Microsoft VS Code/bin" -maxdepth 1 -name "code" -type f 2>/dev/null | head -n 1)
    if [[ -n "$found" && -x "$found" ]]; then
        echo "$found"
        return 0
    fi
    if [[ -n "$CODE_EXECUTABLE" && -x "$CODE_EXECUTABLE" ]]; then
        echo "$CODE_EXECUTABLE"
        return 0
    fi
    if type -p code.cmd &>/dev/null; then
        echo "code.cmd"
        return 0
    fi
    if type -p code &>/dev/null; then
        echo "code"
        return 0
    fi
}

function code_alias_to_auto_open_wsl() {
    local executable="$(_code_client_executable)"
    executable="${executable:-code}"
    alias code="_wsl_auto_open '$executable'"
}

# -- antigravity-ide --

function _antigravity_ide_client_executable() {
    if [[ -n "$LOCALAPPDATA" && -x "$LOCALAPPDATA/Programs/Antigravity IDE/bin/antigravity-ide" ]]; then
        echo "$LOCALAPPDATA/Programs/Antigravity IDE/bin/antigravity-ide"
        return 0
    fi
    local found
    found=$(find /mnt/c/Users -maxdepth 5 -path "*/AppData/Local/Programs/Antigravity IDE/bin/antigravity-ide" -type f 2>/dev/null | head -n 1)
    if [[ -n "$found" && -x "$found" ]]; then
        echo "$found"
        return 0
    fi
    if type -p antigravity-ide &>/dev/null; then
        echo "antigravity-ide"
        return 0
    fi
}

function _antigravity_ide_server_executable() {
    find ~/.antigravity-ide-server/bin -name antigravity-ide-server -type f 2>/dev/null | head -n 1
}

function antigravity_ide_install_extensions() {
    local executable
    executable="$(_antigravity_ide_server_executable)"
    if [[ -z "$executable" || ! -x "$executable" ]]; then
        return 1
    fi
    local installed
    installed="$("$executable" --list-extensions 2>/dev/null)"
    for ext in "$@"; do
        if ! echo "$installed" | grep -qiFx "$ext"; then
            "$executable" --install-extension "$ext" 2>/dev/null || true
        fi
    done
}

function antigravity_ide_install_extensions_from_txt() {
    local path="$1"
    if [[ -z "$path" || ! -f "$path" ]]; then
        return 1
    fi
    local extensions=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="$(echo "$line" | xargs)"
        [[ -n "$line" ]] && extensions+=("$line")
    done <"$path"
    antigravity_ide_install_extensions "${extensions[@]}"
}

function antigravity_ide_alias_to_auto_open_wsl() {
    local executable="$(_antigravity_ide_client_executable)"
    executable="${executable:-antigravity-ide}"
    alias antigravity-ide="_wsl_auto_open '$executable'"
}
