param(
    [string]$ProfilePath = "",
    [switch]$AllHosts
)

function _sph_log_msg {
    param([string]$Message)
    Write-Host -ForegroundColor DarkYellow "-- $Message"
}

$RepoDir = if ($PSScriptRoot) {
    $PSScriptRoot
} else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}

$TargetProfile = if ($ProfilePath) {
    $ProfilePath
} elseif ($AllHosts -and $PROFILE.CurrentUserAllHosts) {
    $PROFILE.CurrentUserAllHosts
} else {
    $PROFILE
}

$parentDir = Split-Path -Parent $TargetProfile
if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $TargetProfile)) {
    New-Item -ItemType File -Path $TargetProfile -Force | Out-Null
}

$sourceLine = ". `"$RepoDir/init.ps1`""
$legacyLine = ". $RepoDir/init.ps1"

$alreadyPresent = (Select-String -LiteralPath $TargetProfile -SimpleMatch $sourceLine -Quiet) -or
    (Select-String -LiteralPath $TargetProfile -SimpleMatch $legacyLine -Quiet)

if (-not $alreadyPresent) {
    Add-Content -LiteralPath $TargetProfile -Value $sourceLine
    Add-Content -LiteralPath $TargetProfile -Value ""
    _sph_log_msg "'$sourceLine' added to $TargetProfile"
} else {
    _sph_log_msg "'$sourceLine' already exists at $TargetProfile"
}

$global:SPH_REPO_DIR = $RepoDir
function global:Update-ShellProfileHelpers {
    git -C $global:SPH_REPO_DIR pull --ff-only
}

Remove-Item -Path Function:\_sph_log_msg -ErrorAction SilentlyContinue
