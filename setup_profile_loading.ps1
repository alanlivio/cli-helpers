function log_msg() { Write-Host -ForegroundColor DarkYellow "--" ($args -join " ") }

$HELPERS_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceLine = ". $HELPERS_DIR/init.ps1"

if (-not (Test-Path $profile)) {
    $folder = [System.IO.Path]::GetDirectoryName($profile)
    New-Item -Path $folder -ItemType Directory | Out-Null
    New-Item $profile -type file | Out-Null
} elseif (-not (Select-String -Path $profile -SimpleMatch $sourceLine -Quiet)) {
    Add-Content $profile $sourceLine
    log_msg "'$sourceLine'added to $profile"
} else {
    log_msg "'$sourceLine' already exist to $profile"
}