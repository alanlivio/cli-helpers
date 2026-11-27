exiftool_set_media_all_dates_to_one_year() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <year>"
        return 1
    fi
    local files=()
    mapfile -t files < <(find . \( -iname "*.jpg" -o -iname "*.mp4" \))
    [[ ${#files[@]} -gt 0 ]] && exiftool -m -AllDates="$1:01:01 00:00:00" "${files[@]}"
}

exiftool_rm_media_data() {
    local files=()
    mapfile -t files < <(find . \( -iname "*.jpg" -o -iname "*.mp4" \))
    [[ ${#files[@]} -gt 0 ]] && exiftool -all= "${files[@]}"
}
