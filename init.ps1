$HELPERS_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# -- load os/<name>.ps1 files -- 

Import-Module "$HELPERS_DIR/os/any.psm1"

$is_windows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
$is_linux = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)
$is_ubuntu = $is_linux -and (Test-Path '/etc/lsb-release' -PathType Leaf)
if ($is_windows) {
    Import-Module (Join-Path $helpers_dir 'os\win.psm1')
}
if ($is_ubuntu -and (Test-Path (Join-Path $helpers_dir 'os/ubu.psm1'))) {
    Import-Module (Join-Path $helpers_dir 'os/ubu.psm1')
}

# -- load <program>.ps1 files --

$helpersDir = "$PSScriptRoot/programs"

Get-ChildItem -Path "$helpersDir\*.psm1" | ForEach-Object {
    $program = $_.BaseName
    if (Get-Command $program -ErrorAction SilentlyContinue) {
        Import-Module $_.FullName
    }
}
