cmake_configure_debug() {
    if [[ -e CMakeLists.txt ]]; then
        cmake -B "_build-Debug-${WSL_DISTRO_NAME:-}${OS:-}" -G Ninja -DCMAKE_EXPORT_COMPILE_programs:BOOL=TRUE -DSTATIC_LINKING=OFF -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Debug "$@"
    else
        cmake .. -G Ninja -DCMAKE_EXPORT_COMPILE_programs:BOOL=TRUE -DSTATIC_LINKING=OFF -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Debug "$@"
    fi
}

cmake_configure_release() {
    if [[ -e CMakeLists.txt ]]; then
        cmake -B "_build-Release-${WSL_DISTRO_NAME:-}${OS:-}" -G Ninja -DCMAKE_EXPORT_COMPILE_programs:BOOL=TRUE -DSTATIC_LINKING=OFF -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release "$@"
    else
        cmake .. -G Ninja -DCMAKE_EXPORT_COMPILE_programs:BOOL=TRUE -DSTATIC_LINKING=OFF -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release "$@"
    fi
}

cmake_build() {
    cmake --build . --target all
}

cmake_clean() {
    cmake --build . --target clean
}

cmake_build_target() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <target>"
        return 1
    fi
    cmake --build . --target "$1"
}

cmake_check() {
    cmake --build . --target check
}

cmake_install() {
    case "${OSTYPE:-}" in
    linux*)
        sudo cmake --install . --prefix /usr
        ;;
    msys*)
        cmake --install .
        ;;
    *)
        sudo cmake --install .
        ;;
    esac
}

cmake_uninstall() {
    local manifest="install_manifest.txt"
    if [[ -e "$manifest" ]]; then
        local i file
        while IFS= read -r i; do
            file="${i%$'\r'}"
            if [[ -e "$file" ]]; then
                log_msg "uninstall $file"
                sudo rm "$file"
            fi
        done <"$manifest"
    else
        log_error "$manifest does not exist"
        return 1
    fi
}

cmake_clean_retain_objs() {
    if [[ -d CMakeFiles ]]; then
        find . -maxdepth 1 -not -name '.' -not -name CMakeFiles -exec rm -rf {} \;
    else
        log_error "there is no CMakeFiles dir"
        return 1
    fi
}

cmake_test_all() {
    ctest
}

cmake_test_target() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <target>"
        return 1
    fi
    cmake --build . --target "$1"
    ctest -R "$1"
}
