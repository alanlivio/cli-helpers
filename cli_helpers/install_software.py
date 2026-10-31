INSTALL_GIT = r"""$ErrorActionPreference = "Stop"

function log_msg { Write-Host -ForegroundColor DarkYellow "--" ($args -join " ") }

log_msg "Installing Git via WinGet..."

$wingetArgs = @(
    "install",
    "--id", "Git.Git",
    "-e",
    "--source", "winget",
    "--scope", "user",
    "--silent",
    "--accept-package-agreements",
    "--accept-source-agreements",
    "--disable-interactivity",
    "--override", '/VERYSILENT /NORESTART /SP- /CLOSEAPPLICATIONS /COMPONENTS="gitlfs,assoc,assoc_sh" /o:UseCredentialManager=Enabled /o:BashTerminalOption=ConHost /o:PathOption=Cmd'
)

& winget @wingetArgs

$gitDir = "$env:LOCALAPPDATA\Programs\Git"

$ucrt64 = Join-Path $gitDir "ucrt64"
$mingw64 = Join-Path $gitDir "mingw64"

if ((Test-Path $ucrt64) -and -not (Test-Path $mingw64)) {
    New-Item -ItemType Junction -Path $mingw64 -Target $ucrt64 -Force | Out-Null
}

if (-not (Test-Path (Join-Path $mingw64 "bin\git-credential-manager.exe"))) {
    $srcGcm = Join-Path $ucrt64 "bin\git-credential-manager.exe"
    if (Test-Path $srcGcm) {
        $binDir = Join-Path $mingw64 "bin"
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
        Copy-Item -Path (Join-Path $ucrt64 "bin\*credential*") -Destination $binDir -Force
    }
}

$contextMenuKeys = @(
    "HKCU:\Software\Classes\Directory\shell\git_shell",
    "HKCU:\Software\Classes\Directory\Background\shell\git_shell",
    "HKCU:\Software\Classes\Drive\shell\git_shell",
    "HKCU:\Software\Classes\Directory\shell\git_gui",
    "HKCU:\Software\Classes\Directory\Background\shell\git_gui",
    "HKCU:\Software\Classes\Drive\shell\git_gui"
)
foreach ($key in $contextMenuKeys) {
    if (Test-Path $key) {
        Remove-Item -Recurse -Force $key -ErrorAction SilentlyContinue
    }
}

$shortcuts = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Git\Git Bash.lnk",
    "$env:USERPROFILE\Desktop\Git Bash.lnk"
)
foreach ($sc in $shortcuts) {
    if (Test-Path $sc) {
        Remove-Item -Force $sc -ErrorAction SilentlyContinue
    }
}

$gitExe = Join-Path $gitDir "cmd\git.exe"
if (Get-Command git -ErrorAction SilentlyContinue) {
    git config --global credential.helper manager
} elseif (Test-Path $gitExe) {
    & $gitExe config --global credential.helper manager
}

log_msg "Git installation and configuration completed."
""".strip()

INSTALL_WINGET = r"""$ErrorActionPreference = "Stop"

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
""".strip()

__all__ = [
    "INSTALL_GIT",
    "INSTALL_WINGET",
]
