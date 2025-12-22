HELPERS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

# -- load os/<name>.bash files --

source "$HELPERS_DIR/os/any.bash"

if [[ $OSTYPE == msys* || -n $WSL_DISTRO_NAME ]]; then
    source "$HELPERS_DIR/os/win.bash"
fi
if [[ $OSTYPE == linux* && -d '/etc/lsb-release' ]]; then
    source "$HELPERS_DIR/os/ubu.bash"
fi

# -- load <program>.bash files --

for file in "$HELPERS_DIR/programs/"*.bash; do
    program=$(basename ${file%.*})
    if type $program &>/dev/null; then
        source $file
    fi
done
