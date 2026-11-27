npx_mermaid_folder_to_svg() {
    if [[ -z "${1:-}" || ! -d "$1" ]]; then
        echo "usage: npx_mermaid_folder_to_svg <folder>"
        return 1
    fi
    local file out
    while IFS= read -r -d '' file; do
        out="${file%.*}.svg"
        if [[ ! -e "$out" || "$file" -nt "$out" ]]; then
            npx -y @mermaid-js/mermaid-cli -i "$file" -o "$out"
        fi
    done < <(find "$1" -type f -name "*.mmd" -print0)
}

npx_marp_folder_to_pdf() {
    if [[ -z "${1:-}" || ! -d "$1" ]]; then
        echo "usage: npx_marp_folder_to_pdf <folder>"
        return 1
    fi
    local file out
    while IFS= read -r -d '' file; do
        out="${file%.*}.pdf"
        if [[ ! -e "$out" || "$file" -nt "$out" ]]; then
            npx -y @marp-team/marp-cli "$file" -o "$out" --allow-local-files
        fi
    done < <(find "$1" -type f -name "*.md" -print0)
}

npx_d2_folder_to_svg() {
    if [[ -z "${1:-}" || ! -d "$1" ]]; then
        echo "usage: npx_d2_folder_to_svg <folder>"
        return 1
    fi
    local file out
    while IFS= read -r -d '' file; do
        out="${file%.*}.svg"
        if [[ ! -e "$out" || "$file" -nt "$out" ]]; then
            npx -y d2 "$file" -o "$out"
        fi
    done < <(find "$1" -type f -name "*.d2" -print0)
}
