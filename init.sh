_sph_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd -P)"

log_error() { printf '\033[00;31m-- %s \033[00m\n' "$*"; }
log_msg() { printf '\033[00;33m-- %s \033[00m\n' "$*"; }
bashrc_reload() { [ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc"; }
eval "sph_update() { git -C \"$_sph_dir\" pull --ff-only; }"

if [ "${OSTYPE#linux}" != "${OSTYPE:-}" ] && [ -f /etc/lsb-release ] && [ -d "$_sph_dir/os" ]; then
    for _sph_file in "$_sph_dir/os/"ubu*.sh; do
        if [ -r "$_sph_file" ]; then
            . "$_sph_file"
        fi
    done
fi

if [ -d "$_sph_dir/programs" ]; then
    for _sph_file in "$_sph_dir/programs/"*.sh; do
        if [ -r "$_sph_file" ]; then
            _sph_prog="${_sph_file##*/}"
            _sph_prog="${_sph_prog%.sh}"
            if command -v "$_sph_prog" >/dev/null 2>&1; then
                . "$_sph_file"
            fi
        fi
    done
fi

if [ -r "$_sph_dir/../dotfiles/init.sh" ]; then
    . "$_sph_dir/../dotfiles/init.sh"
fi

unset _sph_dir _sph_file _sph_prog
