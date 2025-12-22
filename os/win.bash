# -- WSL --

if [[ -n $WSL_DISTRO_NAME ]]; then
    function win_start() {
        type -p wslview >/dev/null || sudo apt install wslu
        wslview $@
    }
    function wsl_install_cuda_cudnn() {
        # https://canonical-ubuntu-wsl.readthedocs-hosted.com/en/latest/tutorials/gpu-cuda/
        sudo apt-key del 7fa2af80
        wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-wsl-ubuntu.pin /tmp/cuda-wsl-ubuntu.pin
        sudo mv /tmp/cuda-wsl-ubuntu.pin /etc/apt/preferences.d/cuda-repository-pin-600
        sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/3bf863cc.pub
        sudo add-apt-repository -y 'deb https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/ /'
        # https://itsfoss.com/key-is-stored-in-legacy-trusted-gpg/
        sudo apt-key export 3BF863CC | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/cudatools.gpg
        sudo apt-get update
        sudo apt-get -y install cuda nvidia-cudnn
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
fi

# -- MSYS2 --

if type -p pacman >/dev/null; then
    alias msys2_search='pacman -s --noconfirm'
    alias msys2_show='pacman -Qi'
    alias msys2_list_installed='pacman -Qqe'
    alias msys2_install='pacman -S --noconfirm'
    alias msys2_uninstall='pacman -R --noconfirm'
    alias msys2_use_same_home='echo db_home: windows >>/etc/nsswitch.conf'
fi