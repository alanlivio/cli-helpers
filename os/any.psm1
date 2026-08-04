# -- basic --

function log_msg { Write-Host -ForegroundColor DarkYellow "--" ($args -join " ") }
function log_error { Write-Host -ForegroundColor DarkRed "--" ($args -join " ") }
function passwd_generate { -join (1..12 | ForEach-Object { [char[]]'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!?' | Get-Random }) }

# -- ps --

function ps_profile_reload() {
    . $PROFILE.CurrentUserAllHosts
}

function ps_is_running_as_sudo { 
    ([System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ps_func_show($name) {
    Get-Content Function:\$name
}

function ps_open_admin_shell_with_cur_profile {
    $profilePath = $profile
    Start-Process wt -ArgumentList "powershell -NoExit -ExecutionPolicy Bypass -File `"$profilePath`"" -Verb RunAs
}

# -- text/ascii --

function text_to_ascii {
    param([Parameter(Mandatory = $true, ValueFromPipeline = $true)][string]$Path)
    process {
        if (Test-Path $Path) {
            $content = Get-Content -Path $Path -Raw
            return ([System.Text.Encoding]::ASCII.GetBytes($content) -join " ")
        }
    }
}

# -- md -- 

function md_assets_cleanup {
    $root = "."
    $assets = "./assets"
    $md_files = Get-ChildItem -Path $root -Filter *.md -File -ErrorAction SilentlyContinue
    if (-not $md_files) { return }
    Get-ChildItem -Path $assets -File | Where-Object {
        @('.png', '.jpeg', '.jpg', '.svg') -contains $_.Extension.ToLower()
    } | ForEach-Object {
        $name = [regex]::Escape($_.Name)
        $pattern = "(?i)(?:\./)?assets/$name"
        $referenced = $false
        foreach ($md in $md_files) {
            if (Select-String -Path $md.FullName -Pattern $pattern -Quiet) { $referenced = $true; break }
        }
        if (-not $referenced) {
            $is_svg = ($_.Extension.ToLower() -eq '.svg')
            Remove-Item -LiteralPath $_.FullName -Force -Verbose
            if ($is_svg) {
                $mmd = [IO.Path]::ChangeExtension($_.FullName, '.mmd')
                if (Test-Path -LiteralPath $mmd) { Remove-Item -LiteralPath $mmd -Force -Verbose }
            }
        }
    }
}

Export-ModuleMember -Function *
