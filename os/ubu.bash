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

function apt_enable_git_ppa() {
    local codename=$(cat /etc/os-release | grep UBUNTU_CODENAME | cut -d = -f 2)
    if ! test -f /etc/apt/sources.list.d/git-core-ubuntu-ppa-$codename.list; then
        sudo apt-add-repository ppa:git-core/ppa --yes
    fi
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

alias ubu_product_name='sudo dmidecode -s system-product-name'
alias ubu_gpu_list="lspci -nn | grep -E 'VGA|Display'"
alias ubu_initd_services_list='service --status-all'

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
    sudo apt install -y latexmk texlive-latex-extra texlive-fonts-extra texlive-extra-utils
}

function ubu_install_node() {
    type -p node >/dev/null || sudo snap install --classic node
    type -p npm >/dev/null || sudo npm install -g npm
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

function ubu_install_miniconda() {
    # https://docs.conda.io/projects/miniconda/en/latest/
    mkdir -p ~/bin/miniconda3
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/bin/miniconda3/miniconda.sh
    bash ~/bin/miniconda3/miniconda.sh -b -u -p ~/bin/miniconda3
    rm -rf ~/bin/miniconda3/miniconda.sh
}

# -- customize --

function gnome_declutter_files() {
    gsettings set org.gnome.desktop.privacy remember-recent-files false
    gsettings set org.gnome.nautilus.list-view default-zoom-level 'small'
    gsettings set org.gnome.nautilus.list-view default-visible-columns "['name', 'size']"
    gsettings set org.gnome.nautilus.list-view use-tree-view true
    gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
}
