param(
    [Alias("WingetOnly")][switch]$winget_only,
    [Alias("GitOnly")][switch]$git_only
)

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
    if (-not (Test-Path $add_path)) { log_error "'$add_path' is not a valid path."; return }
    $path = [Environment]::GetEnvironmentVariable('path', 'User')
    $regex_add_path = [regex]::Escape($add_path)
    $arr_path = $path -split ';' | Where-Object { $_ -notMatch "^$regex_add_path\\?" }
    $new_path = ($arr_path + $add_path) -join ';'
    [Environment]::SetEnvironmentVariable("path", $new_path, 'User')
    $env:path = [Environment]::GetEnvironmentVariable("path", "User") + ";" + [Environment]::GetEnvironmentVariable("path", "Machine")
}

function winget_install() {
    winget list --accept-source-agreements -q $args[0] | Out-Null
    if (-not ($?)) {
        winget install @args --accept-package-agreements --accept-source-agreements --scope user
    }
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

function win_install_git() {
    winget_install Git.Git -e --source winget --silent --disable-interactivity --override '/VERYSILENT /NORESTART /SP- /CLOSEAPPLICATIONS /NOICONS /COMPONENTS="gitlfs" /o:UseCredentialManager=Enabled /o:BashTerminalOption=ConHost /o:PathOption=Cmd'

    $git_dir = "$env:LOCALAPPDATA\Programs\Git"
    $ucrt64 = Join-Path $git_dir "ucrt64"
    $mingw64 = Join-Path $git_dir "mingw64"

    if ((Test-Path $ucrt64) -and -not (Test-Path $mingw64)) {
        New-Item -ItemType Junction -Path $mingw64 -Target $ucrt64 -Force | Out-Null
    }

    $context_menu_keys = @(
        "HKCU:\Software\Classes\Directory\shell\git_shell",
        "HKCU:\Software\Classes\Directory\Background\shell\git_shell",
        "HKCU:\Software\Classes\Drive\shell\git_shell",
        "HKCU:\Software\Classes\Directory\shell\git_gui",
        "HKCU:\Software\Classes\Directory\Background\shell\git_gui",
        "HKCU:\Software\Classes\Drive\shell\git_gui"
    )
    foreach ($key in $context_menu_keys) {
        if (Test-Path $key) {
            Remove-Item -Recurse -Force $key -ErrorAction SilentlyContinue
        }
    }

    $shortcut_folders = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Git",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Git"
    )
    foreach ($folder in $shortcut_folders) {
        if (Test-Path $folder) {
            Remove-Item -Recurse -Force $folder -ErrorAction SilentlyContinue
        }
    }

    $shortcuts = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Git*.lnk",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Git*.lnk",
        "$env:USERPROFILE\Desktop\Git*.lnk",
        "$env:PUBLIC\Desktop\Git*.lnk"
    )
    foreach ($pattern in $shortcuts) {
        Get-Item -Path $pattern -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $git_only) {
        log_msg "Installing WinGet..."
        win_install_winget
    }
    if (-not $winget_only) {
        log_msg "Installing Git via WinGet..."
        win_install_git
    }
}
