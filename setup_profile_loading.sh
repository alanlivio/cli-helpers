function log_msg() { echo -e "\033[00;33m-- $* \033[00m"; }

HELPERS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
sourceLine="source $HELPERS_DIR/init.sh"

if ! grep -q "^$sourceLine\\b" ~/.bashrc; then
    echo "$sourceLine" >> ~/.bashrc
    log_msg "'$sourceLine' added to ~/.bashrc"
else
    log_msg "'$sourceLine' already exists at ~/.bashrc"
fi