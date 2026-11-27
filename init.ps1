$_sph_dir = $PSScriptRoot
$global:SPH_DIR = $_sph_dir
$global:HELPERS_DIR = $_sph_dir

function log_msg { Write-Host -ForegroundColor DarkYellow "--" ($args -join " ") }
function log_error { Write-Host -ForegroundColor DarkRed "--" ($args -join " ") }
function ps_reload_profile { if (Test-Path $PROFILE.CurrentUserCurrentHost) { . $PROFILE.CurrentUserCurrentHost } }
function ps_is_running_as_sudo { ([System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator) }
function ps_func_show($name) { Get-Content "Function:\$name" }
function Update-ShellProfileHelpers { git -C $global:SPH_DIR pull --ff-only }

if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
    $_sph_os_dir = Join-Path $_sph_dir 'os'
    if (Test-Path -LiteralPath $_sph_os_dir -PathType Container) {
        foreach ($_sph_file in (Get-ChildItem -LiteralPath $_sph_os_dir -Filter 'win*.ps1' -File | Sort-Object Name)) {
            . $_sph_file.FullName
        }
    }
}

$_sph_prog_dir = Join-Path $_sph_dir 'programs'
if (Test-Path -LiteralPath $_sph_prog_dir -PathType Container) {
    foreach ($_sph_file in (Get-ChildItem -LiteralPath $_sph_prog_dir -Filter '*.ps1' -File | Sort-Object Name)) {
        if (Get-Command $_sph_file.BaseName -ErrorAction SilentlyContinue) {
            . $_sph_file.FullName
        }
    }
}

$_sph_dotfiles_init = Join-Path (Split-Path -Parent $_sph_dir) 'dotfiles/init.ps1'
if (Test-Path -LiteralPath $_sph_dotfiles_init) {
    . $_sph_dotfiles_init
}

Remove-Variable -Name _sph_dir, _sph_os_dir, _sph_prog_dir, _sph_file, _sph_dotfiles_init -ErrorAction SilentlyContinue
