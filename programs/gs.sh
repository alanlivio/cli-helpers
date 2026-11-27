gs_pdf_compress() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <pdf>"
        return 1
    fi
    gs -dNOPAUSE -dQUIET -dBATCH -sDEVICE=pdfwrite -sOutputFile="${1%.*}-compressed.pdf" "$1" -dPDFSETTINGS=/ebook -dColorImageResolution=200
}

gs_pdf_compress_hard() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <pdf>"
        return 1
    fi
    gs -dNOPAUSE -dQUIET -dBATCH -sDEVICE=pdfwrite -sOutputFile="${1%.*}-compressed.pdf" "$1" -dPDFSETTINGS=/screen
}

gs_pdf_concat() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: ${FUNCNAME[0]} <pdf_1> <pdf_2>"
        return 1
    fi
    gs -dNOPAUSE -dQUIET -dBATCH -sDEVICE=pdfwrite -sOUTPUTFILE="${1%.*}-${2%.*}-concat.pdf" "$1" "$2"
}

gs_pdf_remove_annotations() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <pdf>"
        return 1
    fi
    gs -dNOPAUSE -dQUIET -dBATCH -sDEVICE=pdfwrite -dShowAnnots=false -sOutputFile="${1%.*}-nocomments.pdf" "$1"
}
