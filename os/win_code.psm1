function _win_wsl_auto {
    param(
        [string]$executable,
        [string]$folder_path = (Get-Location).ProviderPath,
        [string[]]$extra_args
    )
    if ([string]::IsNullOrWhiteSpace($folder_path)) {
        $folder_path = (Get-Location).ProviderPath
    }
    $is_unc = (Get-Location).ProviderPath.StartsWith('\\')
    if ($folder_path -like '-*') {
        if ($is_unc) { Push-Location $env:TEMP }
        try {
            & $executable $folder_path @extra_args
        } finally {
            if ($is_unc) { Pop-Location }
        }
        return
    }
    $resolved_path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($folder_path)
    $is_file = if (Test-Path -LiteralPath $resolved_path) {
        Test-Path -LiteralPath $resolved_path -PathType Leaf
    } else {
        [System.IO.Path]::HasExtension($resolved_path)
    }
    if ($resolved_path -match '^\\\\wsl(?:\.localhost|\$)\\[^\\]+$') {
        $resolved_path += '\'
    }
    if ($is_unc) { Push-Location $env:TEMP }
    try {
        if ($resolved_path -match '^\\\\wsl(?:\.localhost|\$)\\([^\\]+)\\(.*)$') {
            $distro_name = $matches[1]
            $linux_path = '/' + ($matches[2] -replace '\\', '/')
            if ($is_file) {
                & $executable --file-uri "vscode-remote://wsl+$distro_name$linux_path" @extra_args
            } else {
                & $executable --folder-uri "vscode-remote://wsl+$distro_name$linux_path" @extra_args
            }
        } else {
            & $executable $resolved_path @extra_args
        }
    } finally {
        if ($is_unc) { Pop-Location }
    }
}

# -- code --

function _code_get_executable {
    if ($env:CODE_EXECUTABLE) { return $env:CODE_EXECUTABLE }
    $found = (Get-Command code -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if ($found) { return $found }
    return "code"
}

function code_install_extensions {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] [string[]]$extensions
    )
    $executable = _code_get_executable
    $installed = @(& $executable --list-extensions)
    foreach ($ext in $extensions) {
        if ($installed -notcontains $ext) {
            & $executable --install-extension $ext
        }
    }
}

function code_install_extensions_from_txt {
    param([string]$path)
    if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path $path)) {
        return $false
    }
    $extensions = Get-Content $path | ForEach-Object { ($_ -split '#')[0].Trim() } | Where-Object { $_ }
    code_install_extensions -extensions $extensions
}

function code_wsl_auto {
    param(
        [Parameter(Position = 0)] [string]$folder_path = (Get-Location).ProviderPath,
        [Parameter(ValueFromRemainingArguments = $true)] [string[]]$extra_args
    )
    $executable = _code_get_executable
    _win_wsl_auto -executable $executable -folder_path $folder_path -extra_args $extra_args
}

function code_alias_to_auto_open_wsl {
    Set-Alias -Name code -Value code_wsl_auto -Scope Global -Option AllScope -Force
}

function code_win_modern_context_menu_add {
    param(
        [string]$name = "code_wsl_auto",
        [string]$title = "Open with Code (Auto WSL)",
        [string]$ps_function = "code_wsl_auto",
        [string]$icon = "powershell.exe,0",
        [switch]$force
    )
    win_modern_context_menu_add -name $name -title $title -ps_function $ps_function -icon $icon -force:$force
}

function code_win_modern_context_menu_remove {
    param([string]$name = "code_wsl_auto")
    win_modern_context_menu_remove -name $name
}

# -- antigravity-ide --

function _antigravity_ide_get_executable {
    $exe = "$env:LOCALAPPDATA\Programs\Antigravity IDE\bin\antigravity-ide.cmd"
    if (Test-Path $exe) { return $exe }
    $exe = "$env:LOCALAPPDATA\Programs\Antigravity IDE\Antigravity IDE.exe"
    if (Test-Path $exe) { return $exe }
    $found = (Get-Command antigravity-ide -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if ($found) { return $found }
    return "antigravity-ide"
}

function antigravity_ide_install_extensions {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] [string[]]$extensions
    )
    $executable = _antigravity_ide_get_executable
    $installed = @(& $executable --list-extensions)
    foreach ($ext in $extensions) {
        if ($installed -notcontains $ext) {
            & $executable --install-extension $ext
        }
    }
}

function antigravity_ide_install_extensions_from_txt {
    param([string]$path)
    if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path $path)) {
        return $false
    }
    $extensions = Get-Content $path | ForEach-Object { ($_ -split '#')[0].Trim() } | Where-Object { $_ }
    antigravity_ide_install_extensions -extensions $extensions
}

function antigravity_ide_wsl_auto {
    param(
        [Parameter(Position = 0)] [string]$folder_path = (Get-Location).ProviderPath,
        [Parameter(ValueFromRemainingArguments = $true)] [string[]]$extra_args
    )
    $executable = _antigravity_ide_get_executable
    _win_wsl_auto -executable $executable -folder_path $folder_path -extra_args $extra_args
}

function antigravity_ide_alias_to_auto_open_wsl {
    Set-Alias -Name antigravity-ide -Value antigravity_ide_wsl_auto -Scope Global -Option AllScope -Force
}

function antigravity_ide_win_modern_context_menu_add {
    param(
        [string]$name = "antigravity_ide_wsl_auto",
        [string]$title = "Open with Antigravity IDE (Auto WSL)",
        [string]$ps_function = "antigravity_ide_wsl_auto",
        [string]$icon,
        [switch]$force
    )
    if (-not $icon) {
        $appExe = "$env:LOCALAPPDATA\Programs\Antigravity IDE\Antigravity IDE.exe"
        if (Test-Path $appExe) {
            $icon = "$appExe,0"
        } else {
            $icon = "powershell.exe,0"
        }
    }
    win_modern_context_menu_add -name $name -title $title -ps_function $ps_function -icon $icon -force:$force
}

function antigravity_ide_win_modern_context_menu_remove {
    param([string]$name = "antigravity_ide_wsl_auto")
    win_modern_context_menu_remove -name $name
}
