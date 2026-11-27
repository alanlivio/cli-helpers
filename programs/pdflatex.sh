latex_clean() {
    rm -f comment.cut ./*.aux ./*.dbx ./*.bbx ./*.cbx ./*.dvi ./*.log ./*.lox ./*.out ./*.lol ./*.pdf ./*.synctex.gz ./_minted-* ./*.bbl ./*.blg ./*.lot ./*.lof ./*.toc ./*.fdb_latexmk ./*.fls ./*.bcf
}

latex_word_count() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <file.tex>"
        return 1
    fi
    texcount -inc -sum "$1" | awk -F': ' '/^Sum count:/ {print $2}'
}

latex_zip_source() {
    local zip_name="${1:-source.zip}"
    [[ "$zip_name" != *.zip ]] && zip_name="${zip_name}.zip"
    local items=()
    local f
    for f in *.tex *.bib *.cls *.png fig figure assets; do
        [[ -e "$f" ]] && items+=("$f")
    done
    if [[ ${#items[@]} -gt 0 ]]; then
        rm -f "$zip_name"
        zip -r "$zip_name" "${items[@]}"
    fi
}
