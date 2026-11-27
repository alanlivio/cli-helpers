meson_configure() {
    local meson_dir="_build"
    if [[ -e meson.build ]]; then
        meson "$meson_dir"
    else
        meson ..
    fi
}

meson_build() {
    ninja
}

meson_install() {
    ninja install
}
