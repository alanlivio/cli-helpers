pandoc_from_any_to_markdown() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <file_name>"
        return 1
    fi
    pandoc -s "$1" -t markdown -o "${1%.*}.md"
}

pandoc_from_docx_to_latex() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <file_name>"
        return 1
    fi
    pandoc -s "$1" -f docx -t latex -o "${1%.*}.tex"
}

pandoc_dir_extension_conv() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: ${FUNCNAME[0]} <extension_from> <extension_to>"
        return 1
    fi
    local i
    for i in *."$1"; do
        [[ -e "$i" ]] || continue
        pandoc -i "$i" -o "${i%.*}.$2"
    done
}
