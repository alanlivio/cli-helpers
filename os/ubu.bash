# -- dotfiles --

function my_declutter() {
    log_msg "# os declutter"
    user_as_sudoer_no_password
    ubu_snap_disable_dir_at_home
    ubu_pro_disable
    sudo apt -y autoremove
}

function my_software() {
    log_msg "# install packages"
    sudo apt update
    sudo apt install -y git curl wget build-essential python3 python3-venv jq net-tools
}

function my_dotfiles_and_update() {
    log_msg "# dotfiles"
    local dotfiles_dir="${DOTFILES:-$HOME/src/dotfiles}"
    if [[ -d "$dotfiles_dir/.git" ]]; then
        if declare -F git_pull_recursive >/dev/null; then
            git_pull_recursive "$dotfiles_dir"
        elif type -p git >/dev/null; then
            git -C "$dotfiles_dir" pull
        fi
    fi
    log_msg "# update pkgs"
    apt_upgrade
    sudo apt -y autoremove
}

alias du_folder_count_files='find . -maxdepth 1 -type f | wc -l'
alias du_folder_count_files_recusive='find . -maxdepth 1 -type f | wc -l'
alias du_folder_list_sorted_by_size='du -ahd 1 | sort -h'
alias du_folder_find_file_with_crlf='find . -not -type d -exec file "{}" ";" | grep CRLF'
alias passwd_generate='echo $(tr -dc "A-Za-z0-9!?%=" < /dev/urandom | head -c 12)'
alias df_root='df -h /'

# -- apt --

function apt_upgrade() {
    log_msg "apt update and upgrade"
    sudo apt update
    sudo apt -y upgrade
}

function apt_fixes() {
    log_msg "apt_fixes"
    sudo dpkg --configure -a
    sudo apt install -f --fix-broken
    sudo apt-get update --fix-missing
    sudo apt -y dist-upgrade
    sudo apt -y autoremove
}

function apt_file_search() {
    : ${1?"Usage: ${FUNCNAME[0]} <file>"}
    type -p apt-file >/dev/null || sudo apt install apt-file
    apt-file search $1
}

# -- deb --

function deb_install_file_from_url() {
    : ${1?"Usage: ${FUNCNAME[0]} <debfile>"}
    local deb_name=$(basename "$1")
    if test ! -f /tmp/$deb_name; then
        curl -O "$1" --create-dirs --output-dir /tmp/
        if test $? != 0; then log_error "curl failed." && return 1; fi
    fi
    sudo dpkg -i /tmp/$deb_name
}

# -- services --

alias ubu_processes_from_user='ps -u $USERNAME|grep -v ps -u'

function kill_from_search() {
    : ${1?"Usage: ${FUNCNAME[0]} <search> [signal]"}
    local search="$1"
    local sig="${2:-}"
    local pids
    pids=$(pgrep -f "$search")
    if [[ -n "$pids" ]]; then
        kill ${sig:+"$sig"} $pids
    fi
}

function ubu_pro_disable() {
    if ! test /etc/apt/apt.conf.d/20apt-esm-hook.conf; then
        sudo systemctl mask apt-news.service
        sudo systemctl mask esm-cache.service
        sudo mv /etc/apt/apt.conf.d/20apt-esm-hook.conf /etc/apt/apt.conf.d/20apt-esm-hook.conf.disabled
    fi
}

function ubu_snap_disable_dir_at_home() {
    sudo snap set system experimental.hidden-snap-folder=true
}

function ubu_increase_swap() {
    sudo fallocate -l 1G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    sudo cp /etc/fstab /etc/fstab.bak
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
}

function ubu_set_linger_background_user() {
    local target_user="${1:-$USER}"
    if ! id "$target_user" >/dev/null 2>&1; then
        sudo useradd -m -s /bin/bash "$target_user"
    fi
    if [ "$(loginctl show-user "$target_user" -p Linger --value 2>/dev/null)" != "yes" ]; then
        sudo loginctl enable-linger "$target_user"
    fi
}

alias ubu_gpu_list="lspci -nn | grep -E 'VGA|Display'"

function ubu_cron_list() {
    local found=0
    local user_cron
    user_cron="$(crontab -l 2>/dev/null || true)"
    if [[ -n "${user_cron//[[:space:]]/}" ]]; then
        echo "Crontab for $USER:"
        echo "$user_cron"
        found=1
    fi
    if sudo -n true 2>/dev/null; then
        local root_cron
        root_cron="$(sudo crontab -l 2>/dev/null || true)"
        if [[ -n "${root_cron//[[:space:]]/}" ]]; then
            [[ $found -eq 1 ]] && echo ""
            echo "Crontab for root:"
            echo "$root_cron"
            found=1
        fi
    fi
    if [[ $found -eq 0 ]]; then
        echo "No crontab entries found."
    fi
}

# -- ssh --

function ssh_fix_permisisons() {
    # https://stackoverflow.com/questions/9270734/ssh-permissions-are-too-open
    chmod 700 $HOME/.ssh/
    chmod 600 $HOME/.ssh/id_rsa
    chmod 600 $HOME/.ssh/id_rsa.pub
}

# -- admin --

function user_as_sudoer_no_password() {
    sudo grep -q "^$USER\\b" /etc/sudoers || echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
}

# -- install --

function ubu_install_latex() {
    sudo apt install -y latexmk texlive-latex-extra texlive-fonts-extra texlive-extra-utils texlive-xetex
}

function ubu_install_gh() {
    # https://github.com/cli/cli/blob/trunk/docs/install_linux.md
    type -p curl >/dev/null || (sudo apt update && sudo apt install curl -y)
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg &&
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg &&
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null &&
        sudo apt update &&
        sudo apt install -y gh
}

# -- wsl --

if [[ -n $WSL_DISTRO_NAME ]]; then
    function wsl_install_docker_gpu() {
        if ! type -p docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
            sudo apt remove -y docker.io docker-compose docker-compose-v2 2>/dev/null
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
            sudo chmod a+r /etc/apt/keyrings/docker.asc
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" |
                sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
            sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            sudo usermod -aG docker $USER
        fi
        if ! type -p nvidia-ctk >/dev/null; then
            sudo install -m 0755 -d /usr/share/keyrings
            curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
            curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
                sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |
                sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
            sudo apt update && sudo apt install -y nvidia-container-toolkit
            sudo nvidia-ctk runtime configure --runtime=docker
        fi
        sudo systemctl enable --now docker 2>/dev/null || sudo service docker restart
    }

    function wsl_fix_libcuda_so_slink() {
        (
            cd /usr/lib/wsl/lib
            sudo rm libcuda.so
            sudo rm libcuda.so.1
            sudo ln -s libcuda.so.1.1 libcuda.so
            sudo ln -s libcuda.so.1.1 libcuda.so.1
        )
    }

    function wsl_set_cmd_start_as_xdg_open() {
        local target_path="/usr/local/bin/xdg-open"
        if [[ -x "$target_path" ]]; then
            return 0
        fi
        printf '%s\n' \
            '#!/usr/bin/env bash' \
            'target="$1"' \
            '[ -z "$target" ] && exit 0' \
            'if [[ "$target" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then' \
            '    if [ -x /mnt/c/Windows/System32/rundll32.exe ]; then' \
            '        /mnt/c/Windows/System32/rundll32.exe url.dll,FileProtocolHandler "$target" >/dev/null 2>&1' \
            '        exit 0' \
            '    elif [ -x /mnt/c/Windows/explorer.exe ]; then' \
            '        /mnt/c/Windows/explorer.exe "$target" >/dev/null 2>&1' \
            '        exit 0' \
            '    fi' \
            'fi' \
            'if [ -e "$target" ]; then' \
            '    win_path="$(wslpath -w "$target" 2>/dev/null || echo "$target")"' \
            '    if [ -x /mnt/c/Windows/System32/rundll32.exe ]; then' \
            '        /mnt/c/Windows/System32/rundll32.exe url.dll,FileProtocolHandler "$win_path" >/dev/null 2>&1' \
            '        exit 0' \
            '    elif [ -x /mnt/c/Windows/explorer.exe ]; then' \
            '        /mnt/c/Windows/explorer.exe "$win_path" >/dev/null 2>&1' \
            '        exit 0' \
            '    fi' \
            'fi' \
            'if [ -x /mnt/c/Windows/System32/rundll32.exe ]; then' \
            '    /mnt/c/Windows/System32/rundll32.exe url.dll,FileProtocolHandler "$target" >/dev/null 2>&1' \
            '    exit 0' \
            'fi' \
            'exit 1' | sudo tee "$target_path" >/dev/null
        sudo chmod +x "$target_path"
    }

    function wsl_fix_path_and_metadata() {
        if ! grep -qs 'metadata,umask=0022,fmask=11' /etc/wsl.conf; then
            echo "[automount]" >>/etc/wsl.conf
            echo "options=\"metadata,umask=0022,fmask=11\"" >>/etc/wsl.conf
        fi
    }
fi
