$HELPERS_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# -- load os/<name>.ps1 files -- 

. "$HELPERS_DIR/os/any.ps1"

$is_windows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
$is_linux = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)
$is_ubuntu = $is_linux -and (Test-Path '/etc/lsb-release')
if ($is_windows) {
    . (Join-Path $helpers_dir 'os\win.ps1')
}
if ($is_ubuntu) {
    . (Join-Path $helpers_dir 'os/ubu.ps1')
}

# -- load <program>.ps1 files --

$helpersDir = "$PSScriptRoot/programs"

Get-ChildItem -Path "$helpersDir\*.ps1" | ForEach-Object {
    $program = $_.BaseName
    if (Get-Command $program -ErrorAction SilentlyContinue) {
        . $_.FullName
    }
}
