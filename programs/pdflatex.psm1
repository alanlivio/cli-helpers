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

function latex_zip_source() {
    param([string]$output = "source.zip")
    if ([string]::IsNullOrWhiteSpace($output)) { $output = "source.zip" }
    if (-not $output.EndsWith(".zip")) { $output += ".zip" }
    $items = @('*.tex', '*.bib', '*.cls', '*.png', 'fig', 'figure', 'assets') | Where-Object { Test-Path $_ }
    if ($items) {
        Compress-Archive -Path $items -DestinationPath $output -Force
    }
}

Export-ModuleMember -Function *
