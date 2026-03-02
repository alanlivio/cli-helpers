function latex_clean() {
    Remove-Item -Force comment.cut, *.aux, *.dbx, *.bbx, *.cbx, *.dvi, *.log, *.lox, *.out, *.lol, *.pdf, *.synctex.gz, _minted-*, *.bbl, *.blg, *.lot, *.lof, *.toc, *.fdb_latexmk, *.fls, *.bcf -ErrorAction SilentlyContinue 
}

function latex_word_count() {
    param([string]$file)
    if ($PSBoundParameters.Keys.Count -lt 1) { log_error "Usage: $($MyInvocation.MyCommand.Name) <file.tex>"; return }
    (texcount -inc -sum $file 2>$null) |
    ForEach-Object {
        if ($_ -match '^Sum count:\s*(\d+)') { $matches[1] }
    }
}