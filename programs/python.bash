alias python_clean_cache='find . | grep -E "(/__pycache__$|\.pyc$|\.pyo$)" | xargs rm -rf'

function pip_install() {
    for pkg in $@; do
        pip show $pkg &>/dev/null || pip install -U $pkg
    done
}

function python_fix_error_externally_managed_environment() {
    python -m pip config set global.break-system-packages true
}

function python_http_server_cur_folder(){
    python -c "import sys, socket, subprocess, signal; signal.signal(signal.SIGINT, signal.SIG_IGN); s = socket.socket(); res = s.connect_ex(('127.0.0.1', 8000)); s.close(); sys.exit('Port 8000 is already in use') if res == 0 else print('http://localhost:8000', flush=True); subprocess.run([sys.executable, '-m', 'http.server', '8000'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)"
}

    
function python_check_torch() {
    python -c "import torch; print(torch.cuda.get_device_name(0))"
}

function python_check_tensorflow() {
    python -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
    python -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
}

function python_pypi_install_local() {
    [[ -d dist ]] && rm -r dist
    [[ -d build ]] && rm -r build
    python -m build . --wheel
    pip install dist/*.whl --force-reinstall
}

function python_pypi_upload_testpypi() {
    [[ -d dist ]] && rm -r dist
    [[ -d build ]] && rm -r build
    rm -rf ./*.egg-info
    python -m build . --wheel
    twine check dist/*
    twine upload --repository testpypi dist/*
}

function python_pypi_upload_pypip() {
    [[ -d dist ]] && rm -r dist
    [[ -d build ]] && rm -r build
    python -m build . --wheel
    twine check dist/*
    twine upload dist/*
}
