function wsl_install_docker_gpu() {
    sudo apt update && sudo apt install -y docker.io docker-compose-v2
    sudo usermod -aG docker $USER
    sudo install -m 0755 -d /usr/share/keyrings
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
    sudo apt update && sudo apt install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl enable --now docker 2>/dev/null || sudo service docker restart
}

function wsl_install_cuda_cudnn() {
    wsl_install_docker_gpu
}

function wsl_fix_libcuda_so_slink() {
    # https://github.com/microsoft/WSL/issues/5663
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
    if [ -f "$target_path" ]; then return; fi
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'target="$1"' \
        '[ -z "$target" ] && exit 0' \
        'if [ -e "$target" ]; then' \
        '    target="$(wslpath -w "$target")"' \
        'fi' \
        'cmd.exe /c start "" "$target" >/dev/null 2>&1' |
        sudo tee "$target_path" >/dev/null
    sudo chmod +x "$target_path"
}

function wsl_fix_path_and_metadata() {
    if ! grep -qs 'metadata,umask=0022,fmask=11' /etc/wsl.conf; then
        echo "[automount]" >>/etc/wsl.conf
        echo "options=\"metadata,umask=0022,fmask=11\"" >>/etc/wsl.conf
    fi
}
