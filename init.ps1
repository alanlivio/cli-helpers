$_sph_dir = $PSScriptRoot
$global:SPH_DIR = $_sph_dir
$global:HELPERS_DIR = $_sph_dir

function log_msg { Write-Host -ForegroundColor DarkYellow "--" ($args -join " ") }
function log_error { Write-Host -ForegroundColor DarkRed "--" ($args -join " ") }
function ps_reload_profile { if (Test-Path $PROFILE.CurrentUserCurrentHost) { . $PROFILE.CurrentUserCurrentHost } }
function ps_is_running_as_sudo { ([System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator) }
function ps_func_show($name) { Get-Content "Function:\$name" }
function Update-ShellProfileHelpers { git -C $global:SPH_DIR pull --ff-only }

foreach ($_sph_sub in @('os', 'programs', 'completions')) {
    if ($_sph_sub -eq 'os' -and -not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
        continue
    }
    $_sph_path = Join-Path $_sph_dir $_sph_sub
    if (Test-Path -LiteralPath $_sph_path -PathType Container) {
        foreach ($_sph_file in (Get-ChildItem -LiteralPath $_sph_path -Filter '*.ps1' -File | Sort-Object Name)) {
            . $_sph_file.FullName
        }
    }
}

if (Test-Path "$HOME/src/dotfiles/init.ps1") {
    . "$HOME/src/dotfiles/init.ps1"
} elseif ($_sph_dir -and (Test-Path (Join-Path (Split-Path -Parent $_sph_dir) 'dotfiles/init.ps1'))) {
    . (Join-Path (Split-Path -Parent $_sph_dir) 'dotfiles/init.ps1')
}

Remove-Variable -Name _sph_dir, _sph_sub, _sph_path, _sph_file -ErrorAction SilentlyContinue
