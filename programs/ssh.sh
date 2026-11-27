ssh_send_to_pub_key_to_remote() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <user@server>"
        return 1
    fi
    ssh "$1" "cat - >> ~/.ssh/authorized_keys" <"$HOME/.ssh/id_rsa.pub"
}

ssh_send_priv_key_to_remote() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <user@server>"
        return 1
    fi
    ssh "$1" "cat - > ~/.ssh/id_rsa && chmod 600 ~/.ssh/id_rsa" <"$HOME/.ssh/id_rsa"
}
