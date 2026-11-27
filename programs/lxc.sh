lxc_list_all() {
    lxc image list
    lxc network list
    lxc list
}

lxc_image_import() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: ${FUNCNAME[0]} <image.tar.gz> <alias>"
        return 1
    fi
    lxc image import "$1" --alias "$2"
}

lxc_profile_assign() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: ${FUNCNAME[0]} <image_name> <profile_name,...>"
        return 1
    fi
    local image_name="$1"
    shift
    lxc assign "$image_name" "$@"
}

lxc_launch() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: ${FUNCNAME[0]} <image_name> <lxc_name>"
        return 1
    fi
    lxc launch "$1" "$2"
}

lxc_pull_file() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: ${FUNCNAME[0]} <lxc_name> <lxc_file>"
        return 1
    fi
    lxc file pull "$1/$2" .
}

lxc_share_dir_home_to_home() {
    if [[ $# -lt 3 ]]; then
        log_error "Usage: ${FUNCNAME[0]} <lxc_name> <lxc_dir> <local_dir>"
        return 1
    fi
    lxc config device add "$1" dev disk "source=/home/$2" "path=/home/ubuntu/$3"
    lxc image import "$1" --alias "$2"
}

lxc_share_dir_remove() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: ${FUNCNAME[0]} <lxc_name> <lxc_dir>"
        return 1
    fi
    lxc config device remove "$1" "$2"
}

lxc_login_as_ubuntu_user() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <lxc_name>"
        return 1
    fi
    lxc exec "$1" -- sudo --user ubuntu --login
}
