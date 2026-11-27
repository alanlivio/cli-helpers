if [[ $- == *i* ]]; then
    alias docker_prune="docker container prune; docker image prune -a"
fi

docker_run_at_same_folder() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: ${FUNCNAME[0]} <image> <command and args>"
        return 1
    fi
    local image="$1"
    shift
    local cwd
    cwd="$(pwd)"
    docker run -v "$cwd:$cwd" -w "$cwd" -it "$image" "$@"
}
