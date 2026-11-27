wget_get_headers() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <url>"
        return 1
    fi
    wget --server-response -O- "$1"
}

wget_post_json() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: ${FUNCNAME[0]} <url> <json>"
        return 1
    fi
    wget --server-response -O- "$1" --post-data="$2" --header='Content-Type:application/json'
}

wget_post_file() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: ${FUNCNAME[0]} <url> <file>"
        return 1
    fi
    wget --server-response -O- "$1" --post-file="$2" --header='Content-Type:application/json'
}

wget_continue() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <url>"
        return 1
    fi
    wget --continue "$1"
}
