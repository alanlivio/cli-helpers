$ErrorActionPreference = "Stop"

function log_msg { Write-Host -ForegroundColor DarkYellow "--" ($args -join " ") }
function log_error { Write-Host -ForegroundColor Red "--" ($args -join " ") }

function github_latest_release_url($repo, $pattern = "*") {
    $api_url = "https://api.github.com/repos/$repo/releases/latest"
    $response = Invoke-RestMethod -Uri $api_url -Method Get -Headers @{ "Accept" = "application/vnd.github.v3+json" }
    if (-not $response) { log_error "Download failed"; return }
    $asset = $response.assets | Where-Object { $_.name -like $pattern -or $_.name -match $pattern } | Select-Object -First 1
    if (-not $asset) { log_error "Asset not found"; return }
    return $asset.browser_download_url
}

function win_path_add($add_path) {
    if (-not (Test-Path $add_path)) { New-Item -ItemType Directory -Path $add_path | Out-Null }
    $path = [Environment]::GetEnvironmentVariable('path', 'User')
    $regex_add_path = [regex]::Escape($add_path)
    $arr_path = $path -split ';' | Where-Object { $_ -notMatch "^$regex_add_path\\?" }
    $new_path = ($arr_path + $add_path) -join ';'
    [Environment]::SetEnvironmentVariable("path", $new_path, 'User')
    $env:path = [Environment]::GetEnvironmentVariable("path", "User") + ";" + [Environment]::GetEnvironmentVariable("path", "Machine")
}

function win_install_winget() {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        log_msg "WinGet is already installed."
        return
    }

    $url = github_latest_release_url "microsoft/winget-cli" "*Microsoft.DesktopAppInstaller*.msixbundle"
    if (-not $url) { return }

    $bundle_file = Join-Path $env:TEMP ([System.IO.Path]::GetFileName($url))
    $web_client = New-Object System.Net.WebClient
    $web_client.DownloadFile($url, $bundle_file)
    try {
        Add-AppxPackage -Path $bundle_file
    } catch {
        log_error "Failed to install WinGet package"
    }
    Remove-Item -Force $bundle_file -ErrorAction SilentlyContinue

    $windows_apps_path = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    if (Test-Path $windows_apps_path) {
        win_path_add $windows_apps_path
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    log_msg "Installing WinGet..."
    win_install_winget
}
