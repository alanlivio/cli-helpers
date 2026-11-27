rsync_download_folder() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: ${FUNCNAME[0]} <remote_folder> <local_folder>"
        return 1
    fi
    rsync -avzP "$1" "$2"
}
