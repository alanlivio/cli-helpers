function log_msg { echo -e "\033[00;33m-- $* \033[00m"; }

HELPERS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
source_line="source $HELPERS_DIR/init.sh"

if ! grep -q "^$source_line\\b" ~/.bashrc; then
    {
        echo "# Added by cli-helpers"
        echo "$source_line"
        echo ""
    } >> ~/.bashrc
    log_msg "'$source_line' added to ~/.bashrc"
else
    log_msg "'$source_line' already exists at ~/.bashrc"
fi