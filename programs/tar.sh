decompress() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <archive-name> [dir-name]"
        return 1
    fi
    local filename
    filename="$(basename "$1")"
    local filename_noext="${filename%.*}"
    local extension="${filename##*.}"
    local dest="${2:-.}"
    local ok=0
    case "$filename" in
    *.tar.bz2 | *.tbz | *.tbz2) tar -xzf "$1" -C "$dest" && ok=1 ;;
    *.gz | *.Z) gunzip -c "$1" >"$dest/$filename_noext" && ok=1 ;;
    *.bz2) tar -xjf "$1" -C "$dest" && ok=1 ;;
    *.zip) unzip "$1" -d "$dest" && ok=1 ;;
    *.zst) tar --use-compress-program=unzstd -xvf "$1" -C "$dest" && ok=1 ;;
    *.xz) tar -xJf "$1" -C "$dest" && ok=1 ;;
    *)
        log_error "$extension is not supported compress."
        return 1
        ;;
    esac
    if [[ $ok -ne 1 ]]; then
        log_error "decompress $1 failed"
        return 1
    fi
}

decompress_from_url() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: ${FUNCNAME[0]} <URL> <dir>"
        return 1
    fi
    local file_name
    file_name="/tmp/$(basename "$1")"
    if [[ ! -e "$file_name" ]]; then
        log_msg "fetching $1 to /tmp/"
        if ! curl -LJ "$1" --create-dirs --output "$file_name"; then
            log_error "curl fail"
            return 1
        fi
    fi
    log_msg "extracting $file_name to $2"
    decompress "$file_name" "$2"
}
