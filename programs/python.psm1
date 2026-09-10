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

function python_venv_activate() {
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

function python_venv_deactivate() {
    if (Get-Command deactivate -ErrorAction SilentlyContinue) {
        deactivate
    }
}

Export-ModuleMember -Function *