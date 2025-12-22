function md_folder_all_mmd_to_svg {
    npm install -g @mermaid-js/mermaid-cli
    Get-ChildItem . -Recurse -Filter *.mmd | ForEach-Object {
        $out = "$($_.DirectoryName)\$([IO.Path]::GetFileNameWithoutExtension($_)).svg"
        if (-not (Test-Path $out) -or $_.LastWriteTime -gt (Get-Item $out).LastWriteTime) {
            mmdc -i $_.FullName -o $out
        }
    }
}

function md_folder_all_marp_to_pdf {
    param([Parameter(Mandatory = $true)][string]$name)
    npm install -g @marp-team/marp-cli
    Get-ChildItem . -Recurse -Filter $name | ForEach-Object {
        $out = "$($_.DirectoryName)\$([IO.Path]::GetFileNameWithoutExtension($_)).pdf"
        if (-not (Test-Path $out) -or $_.LastWriteTime -gt (Get-Item $out).LastWriteTime) {
            marp $_.FullName -o $out --allow-local-files
        }
    }
}
