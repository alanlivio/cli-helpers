alias python_clean_cache='find . | grep -E "(/__pycache__$|\.pyc$|\.pyo$)" | xargs rm -rf'

function pip_install() {
    for pkg in $@; do
        pip show $pkg &>/dev/null || pip install -U $pkg
    done
}

function python_fix_error_externally_managed_environment() {
    python -m pip config set global.break-system-packages true
}

function python_clean_pip_conda_cache() {
    pip cache purge
    conda clean --all --yes
}

function python_install_torch_cuda(){
    pip uninstall torch torchvision torchaudio -y
    pip install --pre torch torch --index-url "https://download.pytorch.org/whl/nightly/cu124"
    echo 'python -c "import torch; print(torch.cuda.get_device_name(0))"'
    python -c "import torch; print(torch.cuda.get_device_name(0))"
}
    
function python_check_torch() {
    python -c "import torch; print(torch.cuda.get_device_name(0))"
}

function python_check_tensorflow() {
    python -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
    python -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
}


function python_pypi_install_local() {
    pip show setuptools &>/dev/null || pip install setuptools
    [[ -d dist ]] && rm -r dist
    [[ -d build ]] && rm -r build
    python -m build . --wheel
    pip install dist/*.whl --force-reinstall
}

function python_pypi_upload_testpypi() {
    pip show setuptools &>/dev/null || pip install setuptools
    pip show twine &>/dev/null || pip install twine
    [[ -d dist ]] && rm -r dist
    [[ -d build ]] && rm -r build
    rm -rf ./*.egg-info
    python -m build . --wheel
    twine check dist/*
    twine upload --repository testpypi dist/*
}

function python_pypi_upload_pypip() {
    pip show setuptools &>/dev/null || pip install setuptools
    pip show twine &>/dev/null || pip install twine
    [[ -d dist ]] && rm -r dist
    [[ -d build ]] && rm -r build
    python -m build . --wheel
    twine check dist/*
    twine upload dist/*
}
