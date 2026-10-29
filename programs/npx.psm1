function npx_mermaid_folder_to_svg {
    param([string]$folder)
    if (-not $folder -or -not (Test-Path $folder -PathType Container)) {
        Write-Host "usage: npx_mermaid_folder_to_svg <folder>"
        return
    }
    Get-ChildItem $folder -Recurse -Filter *.mmd | ForEach-Object {
        $out = "$($_.DirectoryName)\$([IO.Path]::GetFileNameWithoutExtension($_)).svg"
        if (-not (Test-Path $out) -or $_.LastWriteTime -gt (Get-Item $out).LastWriteTime) {
            npx -y @mermaid-js/mermaid-cli -i $_.FullName -o $out
        }
    }
}

function npx_marp_folder_to_pdf {
    param([string]$folder)
    if (-not $folder -or -not (Test-Path $folder -PathType Container)) {
        Write-Host "usage: npx_marp_folder_to_pdf <folder>"
        return
    }
    Get-ChildItem $folder -Recurse -Filter *.md | ForEach-Object {
        $out = "$($_.DirectoryName)\$([IO.Path]::GetFileNameWithoutExtension($_)).pdf"
        if (-not (Test-Path $out) -or $_.LastWriteTime -gt (Get-Item $out).LastWriteTime) {
            npx -y @marp-team/marp-cli $_.FullName -o $out --allow-local-files
        }
    }
}

function npx_d2_folder_to_svg {
    param([string]$folder)
    if (-not $folder -or -not (Test-Path $folder -PathType Container)) {
        Write-Host "usage: npx_d2_folder_to_svg <folder>"
        return
    }
    Get-ChildItem $folder -Recurse -Filter *.d2 | ForEach-Object {
        $out = "$($_.DirectoryName)\$([IO.Path]::GetFileNameWithoutExtension($_)).svg"
        if (-not (Test-Path $out) -or $_.LastWriteTime -gt (Get-Item $out).LastWriteTime) {
            npx -y d2 $_.FullName -o $out
        }
    }
}

Export-ModuleMember -Function *
