function code_cleanup {
    $paths = @(
        "$env:USERPROFILE\.vscode",
        "$env:USERPROFILE\.antigravity",
        "$env:APPDATA\Code\Cache",
        "$env:APPDATA\Code\Code Cache",
        "$env:APPDATA\Code\User\globalStorage",
        "$env:APPDATA\Antigravity IDE\Cache",
        "$env:APPDATA\Antigravity IDE\Code Cache",
        "$env:APPDATA\Antigravity IDE\User\globalStorage"
    )
    foreach ($path in $paths) {
        if (Test-Path $path) {
            Remove-Item -Recurse -Force $path
        }
    }
}


function code_install_extensions {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$extensions
    )
    $installed = @(code --list-extensions)
    foreach ($ext in $extensions) {
        if ($installed -notcontains $ext) {
            code --install-extension $ext
        }
    }
}

function code_install_extensions_from_txt {
    param([string]$path)
    if (Test-Path $path) {
        $extensions = Get-Content $path | Where-Object { $_ -and -not $_.Trim().StartsWith('#') } | ForEach-Object { $_.Trim() }
        code_install_extensions $extensions
    }
}

function code_wsl {
    param(
        [string]$folder_path = (Get-Location).ProviderPath
    )
    if (Test-Path -LiteralPath $folder_path) {
        $folder_path = (Resolve-Path -LiteralPath $folder_path).ProviderPath
    }
    if ($folder_path -match '^\\\\wsl(?:\.localhost|\$)\\[^\\]+$') {
        $folder_path += '\'
    }
    if ($folder_path -match '^\\\\wsl(?:\.localhost|\$)\\([^\\]+)\\(.*)$') {
        $distro_name = $matches[1]
        $linux_path = '/' + ($matches[2] -replace '\\', '/')
        code --remote "wsl+$distro_name" $linux_path
    } else {
        code $folder_path
    }
}

Export-ModuleMember -Function *