if [[ $- == *i* ]]; then
    alias python_clean_cache='find . | grep -E "(/__pycache__$|\.pyc$|\.pyo$)" | xargs rm -rf'
fi

pip_upgrade_pip() {
    local out installed latest
    out="$(python -m pip index versions pip 2>/dev/null)"
    installed="$(echo "$out" | awk '/INSTALLED:/ {print $2}')"
    latest="$(echo "$out" | awk '/LATEST:/ {print $2}')"
    if [[ -n "$installed" && -n "$latest" && "$installed" != "$latest" ]]; then
        python -m pip install --upgrade pip
    fi
}

pip_install() {
    local pkgs=()
    local line
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "-r" && -n "${2:-}" ]]; then
            if [[ -f "$2" ]]; then
                while IFS= read -r line || [[ -n "$line" ]]; do
                    line="${line%%#*}"
                    line="$(echo "$line" | xargs)"
                    [[ -n "$line" ]] && pkgs+=("$line")
                done <"$2"
            fi
            shift 2
        else
            pkgs+=("$1")
            shift 1
        fi
    done

    local pkg name
    for pkg in "${pkgs[@]}"; do
        name="${pkg%%[=><~;@]*}"
        name="$(echo "$name" | xargs)"
        pip show "$name" >/dev/null 2>&1 || pip install -U "$pkg"
    done
}

python_fix_error_externally_managed_environment() {
    python -m pip config set global.break-system-packages true
}

venv_activate_or_init() {
    [[ ! -d .venv ]] && python -m venv .venv
    if [[ -r .venv/bin/activate ]]; then
        local activate_script=".venv/bin/activate"
        . "$activate_script"
    fi
    [[ -f requirements.txt ]] && pip_install -r requirements.txt
}

venv_deactivate() {
    if declare -F deactivate >/dev/null; then
        deactivate
    fi
}

python_http_server_cur_folder() {
    python -c "import sys, socket, subprocess
s = socket.socket()
try:
    s.bind(('', 8000))
    s.close()
except OSError:
    sys.exit('Port 8000 is already in use')
print('http://localhost:8000', flush=True)
try:
    subprocess.run([sys.executable, '-m', 'http.server', '8000'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
except KeyboardInterrupt:
    pass"
}

python_check_torch() {
    python -c "import torch; print(torch.cuda.get_device_name(0))"
}

python_check_tensorflow() {
    python -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
}

python_pypi_install_local() {
    [[ -d dist ]] && rm -r dist
    [[ -d build ]] && rm -r build
    python -m build . --wheel
    pip install dist/*.whl --force-reinstall
}

python_pypi_upload_testpypi() {
    [[ -d dist ]] && rm -r dist
    [[ -d build ]] && rm -r build
    rm -rf ./*.egg-info
    python -m build . --wheel
    twine check dist/*
    twine upload --repository testpypi dist/*
}

python_pypi_upload_pypip() {
    [[ -d dist ]] && rm -r dist
    [[ -d build ]] && rm -r build
    python -m build . --wheel
    twine check dist/*
    twine upload dist/*
}
