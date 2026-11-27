#!/usr/bin/env bash

_sph_log_msg() {
    printf '\033[00;33m-- %s\033[00m\n' "$*"
}

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd -P)"

if [ -n "${1:-}" ]; then
    _sph_rc="$1"
elif [ -n "${SPH_RC_FILE:-}" ]; then
    _sph_rc="$SPH_RC_FILE"
elif [ -n "${ZSH_VERSION:-}" ] || [ "${SHELL##*/}" = "zsh" ]; then
    _sph_rc="$HOME/.zshrc"
else
    _sph_rc="$HOME/.bashrc"
fi

_sph_parent="$(dirname -- "$_sph_rc")"
[ -d "$_sph_parent" ] || mkdir -p "$_sph_parent"
[ -f "$_sph_rc" ] || : >"$_sph_rc"

_sph_source_line=". \"$REPO_DIR/init.sh\""
_sph_legacy_line="source $REPO_DIR/init.sh"

if ! grep -Fq "$_sph_source_line" "$_sph_rc" && ! grep -Fq "$_sph_legacy_line" "$_sph_rc"; then
    printf '\n%s\n' "$_sph_source_line" >>"$_sph_rc"
    _sph_log_msg "'$_sph_source_line' added to $_sph_rc"
else
    _sph_log_msg "'$_sph_source_line' already exists at $_sph_rc"
fi

sph_update() {
    git -C "$REPO_DIR" pull --ff-only
}

unset -f _sph_log_msg
unset _sph_inst_src _sph_rc _sph_parent _sph_source_line _sph_legacy_line
