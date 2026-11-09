function pip_upgrade_pip() {
    $out = python.exe -m pip index versions pip 2>$null
    $installed = ($out | Select-String 'INSTALLED:\s*(\S+)').Matches.Groups[1].Value
    $latest = ($out | Select-String 'LATEST:\s*(\S+)').Matches.Groups[1].Value
    if ($installed -and $latest -and ($installed -ne $latest)) {
        python.exe -m pip install --upgrade pip
    }
}
function pip_install() {
    $packages = @()
    for ($i = 0; $i -lt $args.Count; $i++) {
        if ($args[$i] -eq "-r" -and ($i + 1) -lt $args.Count) {
            $i++
            $file = $args[$i]
            if (Test-Path $file) {
                Get-Content $file | ForEach-Object {
                    $line = ($_ -split '#')[0].Trim()
                    if ($line) {
                        $packages += $line
                    }
                }
            }
        } else {
            $packages += $args[$i]
        }
    }

    foreach ($pkg in $packages) {
        $name = ($pkg -split '[=><~;@]')[0].Trim()
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        try {
            pip show $name *>$null
        } catch { }
        $isMissing = ($LASTEXITCODE -ne 0)
        $ErrorActionPreference = $prevEAP
        if ($isMissing) {
            pip install -U $pkg
        }
    }
}

function venv_activate_or_init() {
    if (-not (Test-Path .venv)) {
        python -m venv .venv
    }
    if (Test-Path .venv\Scripts\Activate.ps1) {
        . .venv\Scripts\Activate.ps1
    } elseif (Test-Path .venv\bin\Activate.ps1) {
        . .venv\bin\Activate.ps1
    }
    if (Test-Path requirements.txt) {
        pip_install -r requirements.txt
    }
}

function venv_deactivate() {
    if (Get-Command deactivate -ErrorAction SilentlyContinue) {
        deactivate
    }
}

Export-ModuleMember -Function *