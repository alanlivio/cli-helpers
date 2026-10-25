$ErrorActionPreference = "Stop"

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
