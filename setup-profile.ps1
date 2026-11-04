function log_msg { Write-Host -ForegroundColor DarkYellow "--" ($args -join " ") }

$helpers_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$source_line = ". $helpers_dir/init.ps1"

if (-not (Test-Path $profile)) {
    $folder = [System.IO.Path]::GetDirectoryName($profile)
    New-Item -Path $folder -ItemType Directory | Out-Null
    New-Item $profile -Type File | Out-Null
}
if (-not (Select-String -Path $profile -SimpleMatch $source_line -Quiet)) {
    Add-Content $profile "# Added by cli-helpers"
    Add-Content $profile $source_line
    Add-Content $profile ""
    log_msg "'$source_line' added to $profile"
} else {
    log_msg "'$source_line' already exists at $profile"
}