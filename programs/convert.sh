convert_heic_at_folder_to_jpg() {
    local found=0
    local file
    for file in *.heic; do
        [[ -e "$file" ]] || continue
        found=1
        convert "$file" "${file/%.heic/.jpg}"
    done
    if [[ $found -eq 0 ]]; then
        log_msg "no .heic file at dir"
    fi
}

convert_pptx_to_compressed_images_pptx() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <pptx_file>"
        return 1
    fi
    [[ -d /tmp/pptx_extracted ]] && rm -rf /tmp/pptx_extracted/
    [[ -e "${1%.*}-compressed.pptx" ]] && rm -rf "${1%.*}-compressed.pptx"
    unzip -q "$1" -d /tmp/pptx_extracted
    local large_images=()
    mapfile -t large_images < <(find /tmp/pptx_extracted/ppt/media -type f -size +500k \( -name '*.jpg' -o -name '*.png' -o -name '*.jpeg' \))
    if [[ ${#large_images[@]} -eq 0 ]]; then
        log_msg "no large images"
        return 0
    fi
    local image
    for image in "${large_images[@]}"; do
        log_msg "compressing $(basename "$image")"
        mogrify -sampling-factor 4:2:0 -quality 50 -strip "$image"
    done
    local cwd
    cwd="$(pwd)"
    (
        cd /tmp/pptx_extracted/ || return 1
        log_msg "creating $cwd/${1%.*}-compressed.pptx"
        zip -9 -q -r "$cwd/${1%.*}-compressed.pptx" ./*
    )
}
