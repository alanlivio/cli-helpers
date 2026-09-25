HELPERS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

function log_error { echo -e "\033[00;31m-- $* \033[00m";}
function log_msg { echo -e "\033[00;33m-- $* \033[00m";}
alias bashrc_reload='source $HOME/.bashrc'

# -- load os/<name>.bash files --

if [[ -n $WSL_DISTRO_NAME ]]; then
    source "$HELPERS_DIR/os/wsl.bash"
fi
if [[ $OSTYPE == linux* && -f '/etc/lsb-release' ]]; then
    source "$HELPERS_DIR/os/ubu.bash"
fi

# -- load <program>.bash files --

for file in "$HELPERS_DIR/programs/"*.bash; do
    program=$(basename ${file%.*})
    if type $program &>/dev/null; then
        source $file
    fi
done
