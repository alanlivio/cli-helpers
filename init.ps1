$HELPERS_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
function log_msg { Write-Host -ForegroundColor DarkYellow "--" ($args -join " ") }
function log_error { Write-Host -ForegroundColor DarkRed "--" ($args -join " ") }
function ps_reload_profile() { . $PROFILE.CurrentUserCurrentHost }
function ps_is_running_as_sudo { ([System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator) }
function ps_func_show($name) { Get-Content Function:\$name }

# -- load os/<name>.ps1 files -- 

$is_windows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
$is_linux = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)
$is_ubuntu = $is_linux -and (Test-Path '/etc/lsb-release' -PathType Leaf)
if ($is_windows) {
    Import-Module (Join-Path $helpers_dir 'os\win.psm1')
}
if ($is_ubuntu -and (Test-Path (Join-Path $helpers_dir 'os\ubu.psm1'))) {
    Import-Module (Join-Path $helpers_dir 'os\ubu.psm1')
}

# -- load <program>.ps1 files --

$helpersDir = "$PSScriptRoot\programs"

Get-ChildItem -Path "$helpersDir\*.psm1" | ForEach-Object {
    $program = $_.BaseName
    if (Get-Command $program -ErrorAction SilentlyContinue) {
        Import-Module $_.FullName
    }
}
