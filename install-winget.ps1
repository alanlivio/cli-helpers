$ErrorActionPreference = "Stop"

$response = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -Headers @{ "Accept" = "application/vnd.github.v3+json" }
$asset = $response.assets | Where-Object { $_.name -like "*Microsoft.DesktopAppInstaller*.msixbundle" } | Select-Object -First 1
if (-not $asset) {
    Write-Host -ForegroundColor Red "-- Asset not found"
    return
}

$bundle_file = Join-Path $env:TEMP ([System.IO.Path]::GetFileName($asset.browser_download_url))
$web_client = New-Object System.Net.WebClient
$web_client.DownloadFile($asset.browser_download_url, $bundle_file)
try {
    Add-AppxPackage -Path $bundle_file
} catch {
    Write-Host -ForegroundColor Red "-- Failed to install WinGet package"
}
Remove-Item -Force $bundle_file -ErrorAction SilentlyContinue
