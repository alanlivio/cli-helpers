if [ -n "${BASH_SOURCE[0]:-}" ]; then
    _sph_src="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
    eval '_sph_src="${(%):-%x}"'
else
    _sph_src="$0"
fi

_sph_dir="$(cd -- "$(dirname -- "$_sph_src")" >/dev/null 2>&1 && pwd -P)"
SPH_DIR="$_sph_dir"
HELPERS_DIR="$_sph_dir"
export SPH_DIR HELPERS_DIR

log_error() { printf '\033[00;31m-- %s \033[00m\n' "$*"; }
log_msg() { printf '\033[00;33m-- %s \033[00m\n' "$*"; }
bashrc_reload() { [ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc"; }
sph-update() { git -C "$SPH_DIR" pull --ff-only; }

for _sph_sub in os programs completions; do
    if [ -d "$_sph_dir/$_sph_sub" ]; then
        for _sph_file in "$_sph_dir/$_sph_sub/"*.sh; do
            if [ -r "$_sph_file" ]; then
                . "$_sph_file"
            fi
        done
    fi
done

if [ -r "$HOME/src/dotfiles/init.sh" ]; then
    . "$HOME/src/dotfiles/init.sh"
elif [ -n "${_sph_dir:-}" ] && [ -r "$_sph_dir/../dotfiles/init.sh" ]; then
    . "$_sph_dir/../dotfiles/init.sh"
fi

unset _sph_src _sph_dir _sph_sub _sph_file
