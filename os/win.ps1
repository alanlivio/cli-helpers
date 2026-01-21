# -- os_upgrade --

function win_os_upgrade() {
    log_msg "win_os_upgrade"
    if (-not (ps_is_running_as_sudo)) { log_msg "not running as admin. skipping"; return }
    # https://gist.github.com/billpieper/a39173afa0b343a14ddeeb1d79ab14ea
    if (-Not(Get-Command Install-WindowsUpdate -errorAction SilentlyContinue)) {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module -Name PSWindowsUpdate -Scope CurrentUser -Force
        # Add-WUServiceManager -MicrosoftUpdate -Confirm:$false | Out-Null
    }
    $(Install-WindowsUpdate -AcceptAll -IgnoreReboot) | Where-Object {
        if ($_ -is [string]) {
            $_.Split('', [System.StringSplitOptions]::RemoveEmptyEntries)
        }
    }
}

# -- admin --

function win_admin_enable_administrator() {
    if (-not (ps_is_running_as_sudo)) { log_msg "not running as admin. skipping"; return }
    net user administrator /active:yes
}

function win_admin_disable_administrator() {
    if (-not (ps_is_running_as_sudo)) { log_msg "not running as admin. skipping"; return }
    net user administrator /active:no
}

function win_admin_add_current_user {
    if (-not (ps_is_running_as_sudo)) { log_msg "not running as admin. skipping"; return }
    $current_user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    net localgroup 'Administrators' $current_user /add
}

function win_admin_romove_current_user() {
    if (-not (ps_is_running_as_sudo)) { log_msg "not running as admin. skipping"; return }
    $current_user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $raw = net localgroup 'Administrators'
    $members = $raw |
    ForEach-Object { $_.Trim() } |
    Where-Object {
        $_ -and
        $_ -notmatch 'command completed successfully' -and
        $_ -notmatch 'Alias name' -and
        $_ -notmatch 'Comment' -and
        $_ -notmatch 'Members' -and
        $_ -notmatch '^-+$'
    }
    if ($members.Count -eq 1) {
        Write-Host "There is only on admin Nothing to do."
        return
    }
    net localgroup 'Administrators' $current_user /delete
}

# -- install -- 

function win_install_exe_from_zip() {
    # if the basename of extractPath exist inside extracted Path so get from inside that folder
    # For example: win_install_exe_from_zip ""...\vlc-3.0.21.zip" "...\bin\vlc-3.0.21" "vlc.exe" 
    # there is a vlc-3.0.21 folder inside vlc-3.0.21-win64.zip
    # so the content of that nested folder is used
    param(
        [Parameter(Mandatory = $true)][string]$url_or_path_to_zip,
        [Parameter(Mandatory = $true)][string]$extract_path, # it should has a name if the zip has no main folder
        [Parameter(Mandatory = $true)][string]$exe_path_on_zip # exe inside the zip
    )
    $exe_path = Join-Path $extract_path $exe_path_on_zip
    $source_zip_file_path = ""
    if (!(Test-Path $exe_path)) {
        # download
        if ($url_or_path_to_zip.StartsWith("http://") -or $url_or_path_to_zip.StartsWith("https://")) {
            $url = New-Object System.Uri($url_or_path_to_zip)
            $derived_zip_file_name = [System.IO.Path]::GetFileName($url.LocalPath)
            $out_zip = Join-Path $env:TEMP $derived_zip_file_name
            if (Test-Path $out_zip) {
                log_msg "skip download and using existing $out_zip"
            } else {
                $web_client = New-Object System.Net.WebClient
                $web_client.DownloadFile($url, $out_zip)
                if (!(Test-Path $out_zip)) { log_error "download failed"; return }
            }
            $source_zip_file_path = $out_zip
        } else {
            $source_zip_file_path = $url_or_path_to_zip
        }
        # extract, using a randomExtractFolder may needed when no internal folder.
        $random_extract_folder = [System.Guid]::NewGuid().ToString().Replace("-", "")
        $temp_extract_path = Join-Path $env:TEMP $random_extract_folder
        New-Item -ItemType Directory -Path $temp_extract_path | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        try { 
            [System.IO.Compression.ZipFile]::ExtractToDirectory($source_zip_file_path, $temp_extract_path) 
        } catch { log_error "extract failed"; return }
        if (!(Test-Path $extract_path)) { New-Item -ItemType Directory -Path $extract_path | Out-Null }
        # if the basename of extract_path exist inside extracted Path so get from inside that folder
        $extract_path_basename = (Split-Path -Path $extract_path -Leaf)
        if (Test-Path (Join-Path $temp_extract_path $extract_path_basename)) {
            Copy-Item -Path "$temp_extract_path\$extract_path_basename\*" -Destination $extract_path -Recurse -Force
        } else {
            Copy-Item -Path "$temp_extract_path\*" -Destination $extract_path -Recurse -Force
        }
    }
}

function win_install_vlc() {
    $vlc_exists = Get-ChildItem -Path "$env:LOCALAPPDATA\Programs" -Directory -Filter "vlc-*" | Where-Object { $_.Name -match "^vlc-\d+\.\d+\.\d+$" }
    if ($vlc_exists) { return; }
    $vlc_latest_win64_url = "https://get.videolan.org/vlc/last/win64/"
    $web_request = Invoke-WebRequest -Uri $vlc_latest_win64_url -Method Get -ErrorAction Stop
    $vlc_zip_link = $web_request.Links | Where-Object { $_.href -like "*win64.zip" } | Select-Object -First 1
    if (-not ($vlc_zip_link)) { log_error "Download failed"; return }
    $vlc_zip = $vlc_zip_link.href
    $url = "https://get.videolan.org/vlc/last/win64/$vlc_zip"
    $pkg_name = $vlc_zip -replace '-win64\.zip$'
    win_install_exe_from_zip $url "$env:LOCALAPPDATA\Programs\$pkg_name" "vlc.exe"
    win_startmenu_add_lnk_to_allapps "$env:LOCALAPPDATA\Programs\$pkg_name\vlc.exe"
}

function win_install_obs() {
    if (Test-Path "$env:LOCALAPPDATA\Programs\OBS\bin\64bit\obs64.exe") { return; }
    $api_url = "https://api.github.com/repos/obsproject/obs-studio/releases/latest"
    $response = Invoke-RestMethod -Uri $api_url -Method Get -Headers @{"Accept" = "application/vnd.github.v3+json" }
    if (-not ($response)) { log_error "Download failed"; return }
    $version = $response.tag_name
    $url = "https://github.com/obsproject/obs-studio/releases/download/$version/OBS-Studio-$version-Windows-x64.zip"
    win_install_exe_from_zip $url "$env:LOCALAPPDATA\Programs\OBS" "bin\64bit\obs64.exe"
    win_startmenu_add_lnk_to_allapps "$env:LOCALAPPDATA\Programs\OBS\bin\64bit\obs64.exe" OBS
}

function win_install_gh() {
    if (Test-Path "$env:LOCALAPPDATA\Programs\gh\bin\gh.exe") { return; }
    $api_url = "https://api.github.com/repos/cli/cli/releases/latest"
    $response = Invoke-RestMethod -Uri $api_url -Method Get -Headers @{"Accept" = "application/vnd.github.v3+json" }
    if (-not ($response)) { log_error "Download failed"; return }
    $version = $response.tag_name.Substring(1)
    $url = "https://github.com/cli/cli/releases/download/v$version/gh_${version}_windows_amd64.zip" 
    win_install_exe_from_zip $url "$env:LOCALAPPDATA\Programs\gh" "bin\gh.exe"
    win_path_add "$env:LOCALAPPDATA\Programs\gh\bin"
}

function win_install_node() {
    if (Test-Path "$env:LOCALAPPDATA\Programs\nodejs") { return; }
    $node_index_url = "https://nodejs.org/dist/index.json"
    $node_index = Invoke-RestMethod -Uri $node_index_url
    $latest_lts = $node_index | Where-Object { $_.lts } | Select-Object -First 1
    $version = $latest_lts.version.TrimStart("v")  # e.g. "20.12.2"
    $arch = "x64"
    $url = "https://nodejs.org/dist/v$version/node-v$version-win-$arch.zip"
    win_install_exe_from_zip $url "$env:LOCALAPPDATA\Programs\nodejs" "node-v$version-win-$arch\node.exe"
    win_path_add "$env:LOCALAPPDATA\Programs\nodejs\node-v$version-win-$arch\"
}

function win_install_latex() {
    winget_install MikTex.MikTex
    # install perl required by latexmk 
    if (Test-Path "$env:LOCALAPPDATA\Programs\StrawberryPerl") { return; } 
    $api_url = "https://api.github.com/repos/StrawberryPerl/Perl-Dist-Strawberry/releases/latest"
    $response = Invoke-RestMethod -Uri $api_url -Method Get -Headers @{"Accept" = "application/vnd.github.v3+json" }
    if (-not ($response)) { log_error "Download failed"; return }
    $asset = $response.assets | Where-Object {
        $_.name -match '^strawberry-perl-[\d\.]+-64bit-portable\.zip$'
    } | Select-Object -First 1
    $url = $asset.browser_download_url
    log_msg "download and extracting StrawberryPerl (~15min)"
    win_install_exe_from_zip $url "$env:LOCALAPPDATA\Programs\StrawberryPerl" "perl\bin\perl.exe"
    log_msg "download and extracting finished"
    win_path_add("${env:localappdata}\Programs\StrawberryPerl\perl\bin")
}

function win_install_ffmpeg() {
    winget_install Gyan.FFmpeg
    win_path_add("${env:localappdata}\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-7.1.1-full_build\bin")
}

function win_install_vim() {
    if (Test-Path "$env:LOCALAPPDATA\Programs\vim\vim91\vim.exe") { return; }  
    winget install vim.vim --location="$env:LOCALAPPDATA\Programs\vim"
    win_path_add "$env:LOCALAPPDATA\Programs\vim\vim91"
}

function win_install_tor() {
    if (Test-Path "$env:LOCALAPPDATA\Programs\TorBrowser") { return; } # winget -q return false for TorBrowser
    winget install TorProject.TorBrowser --location="$env:LOCALAPPDATA\Programs\TorBrowser" 
    win_startmenu_add_lnk_to_allapps "$env:LOCALAPPDATA\Programs\TorBrowser\Browser\firefox.exe" TorBrowser
}

# -- winget --

function winget_upgrade() {
    log_msg "winget update"
    winget upgrade --all --accept-package-agreements --accept-source-agreements --scope user
}

function winget_install() {
    winget list --accept-source-agreements -q $args[0] | Out-Null # first arg is the id
    if (-not($?)) {
        winget install "$args" --accept-package-agreements --accept-source-agreements
    }
}

function winget_uninstall() {
    param ([Parameter(Mandatory = $true)][string] $pkg)
    winget list --accept-source-agreements -q $pkg | Out-Null
    if ($?) {
        winget uninstall $pkg
    }
}

function winget_fix_installation() {
    sudo {
        Remove-Item -Recurse "${env:localappdata}\Temp\WinGet\"  -Force -ErrorAction SilentlyContinue
        Remove-Item -Recurse "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" -Force -ErrorAction SilentlyContinue
        Remove-Item -Recurse "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*"  -Force -ErrorAction SilentlyContinue
        winget source update
    }
}

# -- env --

function win_env_add($name, $value) {
    [Environment]::SetEnvironmentVariable($name, $value, 'User')
}

function win_env_add_machine($name, $value) {
    if (Test-IsNotAdmin) { log_error "no admin. skipping."; return }
    [Environment]::SetEnvironmentVariable($name, $value, 'Machine')
}

function win_env_list() {
    [Environment]::GetEnvironmentVariables()
}

# -- path --

function win_path_reload() {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine) + ";" + [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
}

function win_path_add($addPath) {
    if (-not(Test-Path $addPath)) { log_error "'$addPath' is not a valid path."; return }
    $path = [Environment]::GetEnvironmentVariable('path', 'User')
    $regexAddPath = [regex]::Escape($addPath)
    $arrPath = $path -split ';' | Where-Object { $_ -notMatch "^$regexAddPath\\?" }
    $newpath = ($arrPath + $addPath) -join ';'
    [Environment]::SetEnvironmentVariable("path", $newpath, 'User')
}

function win_path_list() {
    (Get-ChildItem Env:Path).Value -split ';'
}

# -- explorer --

function explorer_restart() {
    log_msg "explorer_restart"
    Stop-Process -Force -ErrorAction SilentlyContinue -ProcessName Explorer
}

function explorer_reset_shell_folders {
    $folders_expandable = @{
        "My Music"    = "%USERPROFILE%\Music"
        "Personal"    = "%USERPROFILE%\Documents"
        "My Video"    = "%USERPROFILE%\Videos"
        "My Pictures" = "%USERPROFILE%\Pictures"
    }
    $path_key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    New-Item -Path $path_key -Force | Out-Null
    foreach ($name in $folders_expandable.Keys) {
        $expand_value = $folders_expandable[$name]
        $real_path = [Environment]::ExpandEnvironmentVariables($expand_value)
        Set-ItemProperty -Path $path_key -Name $name -Value $expand_value -Type ExpandString -Force | Out-Null
        if (-not (Test-Path -LiteralPath $real_path)) {
            New-Item -ItemType Directory -Path $real_path -Force | Out-Null
        }
    }
    explorer_restart
}


function explorer_folder_use_pictures_icon {
    param ([string]$FolderPath)
    if (-Not (Test-Path $FolderPath)) {
        log_error "The folder '$FolderPath' does not exist." -ForegroundColor Red
        return
    }
    $DesktopIniPath = "$FolderPath\desktop.ini"
    @"
[.ShellClassInfo]
IconResource=%SystemRoot%\system32\imageres.dll,-113
IconFile=%SystemRoot%\system32\imageres.dll,-113
IconIndex=0
"@ | Set-Content -Path $DesktopIniPath -Encoding UTF8 -Force
    attrib +r "$FolderPath" /s /d > $null
    attrib +h "$DesktopIniPath" > $null
    log_msg "Successfully set the icon for '$FolderPath' to match the Pictures folder."
}

function explorer_hide_home_dotfiles {
    $paths = Get-ChildItem -LiteralPath $env:userprofile -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like '.*' -or $_.Name -like '*.lock' } |
    Select-Object -ExpandProperty FullName
    $paths = $paths | Where-Object { Test-Path -LiteralPath $_ }
    $hidden = [IO.FileAttributes]::Hidden
    foreach ($p in $paths) {
        $i = Get-Item -LiteralPath $p -Force
        if (-not $i.Attributes.HasFlag($hidden)) { $i.Attributes = $i.Attributes -bor $hidden }
    }
}

function explorer_hide_unused_and_shell_folders {
    $folders = foreach ($r in $roots) { foreach ($s in $subs) { Join-Path $r $s } }
    $folders_extra = 'CrossDevice', 'vimfiles', 'vscode-remote-wsl', 'Contacts', 'Music', 'Games', 'Videos', 'Links', 'Favorites', 'Saved Games', 'Searches' |
    ForEach-Object { Join-Path $env:userprofile $_ }
    $paths = $folders + $folders_extra
    $paths = $paths | Sort-Object -Unique | Where-Object { Test-Path -LiteralPath $_ }
    $hidden = [IO.FileAttributes]::Hidden
    foreach ($p in $paths) {
        $i = Get-Item -LiteralPath $p -Force
        if (-not $i.Attributes.HasFlag($hidden)) { $i.Attributes = $i.Attributes -bor $hidden }
    }
}


# -- wsl --

function bash_ic() {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$cmd
    )
    bash -i -c "$cmd"
}

function wsl_list() {
    wsl -l -v
}

function wsl_list_running() {
    wsl -l -v --running
}

function wsl_get_default() {
    [System.Text.Encoding]::Unicode.GetString([System.Text.Encoding]::UTF8.GetBytes((wsl -l))) -split '\s\s+' | ForEach-Object {
        if ($_.Contains('(')) {
            return $_.Split(' ')[0]
        }
    }
}

function wsl_get_default_version() {
    Foreach ($i in (wsl -l -v)) {
        if ($i.Contains('*')) {
            return $i.Split(' ')[-1]
        }
    }
}

function wsl_terminate() {
    wsl -t (wsl_get_default)
}


function wsl_use_same_home() {
    log_msg "setup wsl to use same home"
    log_msg "target wsl is $(wsl_get_default)"
    if ((wsl echo '$HOME').Contains("Users")) {
        log_msg "WSL already use windows UserProfile as home."
        return
    }
    log_msg "terminate wsl"
    wsl_terminate
    $user_name = (wsl whoami)
    log_msg "change default dir to /mnt/c/Users/"
    wsl -u root skill -KILL -u $user_name
    wsl -u root usermod -d /mnt/c/Users/$env:UserName $user_name
    log_msg "create a link /home/user at /mnt/c/Users/user"
    wsl -u root rm -rf /home/$user_name
    wsl -u root ln -s /mnt/c/Users/$env:UserName /home/$user_name
}

function wsl_fix_metadata() {
    log_msg "wsl_fix_metadata"
    # https://docs.microsoft.com/en-us/windows/wsl/wsl-config
    # https://github.com/Microsoft/WSL/issues/3138
    # https://devblogs.microsoft.com/commandline/chmod-chown-wsl-improvements/
    log_msg "terminate wsl"
    wsl_terminate
    wsl -u root bash -c 'echo "[automount]" > /etc/wsl.conf'
    wsl -u root bash -c 'echo "options=\"metadata,umask=0022,fmask=11\"" >> /etc/wsl.conf'
}

# -- office --

function win_office_disable_warn_local_link {
    # requireq admin
    $keys = @(
        "HKCU:\Software\Microsoft\Office\16.0\Common\Security",
        "HKCU:\Software\Policies\Microsoft\Office\16.0\Common\Security"
    )

    foreach ($path in $keys) {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "DisableHyperlinkWarning" -Value 1 -Type DWord -Force | Out-Null
    }
}

function office_onenote_deeplink_from_url {
    param([Parameter(Mandatory)][string]$url)

    if (-not $script:onenote_cache) { $script:onenote_cache = @{} }
    if ($script:onenote_cache.ContainsKey($url)) { return $script:onenote_cache[$url] }

    Add-Type -AssemblyName System.Web | Out-Null
    $uri = [Uri]$url
    $qs = [System.Web.HttpUtility]::ParseQueryString($uri.Query)

    $resid = $qs['resid']
    $root_resid = ($resid -split '!')[0]
    $wd = $qs['wd']
    $decoded_wd = [System.Web.HttpUtility]::UrlDecode($wd)
    $decoded_wd -match 'target\((.+)\)' | Out-Null
    $target = $Matches[1]

    $parts = $target -split '\|'
    $notebook_file = $parts[0]
    $section_split = $parts[1] -split '/', 2
    $section_guid = $section_split[0]
    $section_name = $section_split[1]
    $page_guid = if ($parts.Count -ge 3 -and $parts[2]) { ($parts[2] -replace '/$', '') } else { $null }

    $section_name_escaped = [System.Uri]::EscapeDataString($section_name)
    $onenote = "onenote:https://d.docs.live.net/$root_resid/$notebook_file#$section_name_escaped&section-id={$section_guid}"
    if ($page_guid) { $onenote += "&page-id={$page_guid}" }
    $onenote += "&end"

    $script:onenote_cache[$url] = $onenote
    $onenote
}

# -- system --

function win_system_disable_power_sleep_buttons() {
    powercfg -setacvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 0
}

function win_system_image_scan_cleanup() {
    if (Test-IsNotAdmin) { log_error "no admin. skipping."; return }
    cmd.exe /c 'sfc /scannow'
    dism.exe /Online /Cleanup-image /Restorehealth    
    dism /Online /Cleanup-Image /RestoreHealth
}

function win_system_policy_reset() {
    if (Test-IsNotAdmin) { log_error "no admin. skipping."; return }
    cmd.exe /C 'RD /S /Q %WinDir%\System32\GroupPolicyUsers '
    cmd.exe /C 'RD /S /Q %WinDir%\System32\GroupPolicy '
    gpupdate.exe /force
}

function win_system_enable_ssh_agent() {
    if (Test-IsNotAdmin) { log_error "no admin. skipping."; return }
    Set-Service ssh-agent -StartupType Automatic
    Start-Service ssh-agent
    Get-Service ssh-agent
    ssh-add "${env:userprofile}\\.ssh\\id_rsa"
}

# -- onedrive --

function win_onedrive_make_folder_avaliable() {
    param ([string]$Path = (Get-Location).Path)
    log_msg "win_onedrive_make_folder_avaliable $Path"
    $files = Get-ChildItem -Path $Path -File -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        # Check if the file is a reparse point (i.e., online-only OneDrive file)
        if (($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint) {
            $fs = [System.IO.FileStream]::new($file.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
            $null = $fs.Read([byte[]]::new(1024), 0, 1024); $fs.Close(); $fs.Dispose()
        }
    }
}


function win_onedrive_reset() {
    & "C:\Program Files\Microsoft OneDrive\onedrive.exe" /reset
}

# -- startmenu/desktop --

function win_startmenu_add_lnk_to_allapps {
    param (
        [Parameter(Mandatory = $true)][string]$exePath,                # Path to the .exe file
        [Parameter(Mandatory = $false)][string]$shortcutName           # Optional shortcut name
    )
    if (-not (Test-Path $exePath)) {
        log_error "The specified executable path does not exist: $exePath"
        return
    }
    if (-not $shortcutName) {
        $shortcutName = [System.IO.Path]::GetFileNameWithoutExtension($exePath) + ".lnk"
    } elseif (-not $shortcutName.EndsWith(".lnk")) {
        $shortcutName += ".lnk"
    }
    $startMenuFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    if (-not (Test-Path $startMenuFolder)) {
        log_error "The Start Menu folder does not exist: $startMenuFolder"
        return
    }
    $shortcutPath = Join-Path -Path $startMenuFolder -ChildPath $shortcutName
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $exePath
        $shortcut.WorkingDirectory = (Split-Path -Parent $exePath)
        $shortcut.Description = "Shortcut to $(Split-Path -Leaf $exePath)"
        $shortcut.Save()
        log_msg "Shortcut successfully created: $shortcutPath"
    } catch {
        log_error "An error occurred while creating the shortcut: $_"
    }
}

function win_desktop_as_slideshow_from_folder() {
    param ([string] $folder)
    if (-Not (Test-Path $folder)) {
        log_error "The folder '$folder' does not exist. Please provide a valid folder."
        exit 1
    }
    $folder = (Get-Item $folder).FullName
    $slideshow_key = "HKCU:\Control Panel\Personalization\Desktop Slideshow"
    $desktop_key = "HKCU:\Control Panel\Desktop"
    $wallpapers_key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers"
    New-Item $slideshow_key -Force | Out-Null
    New-Item $desktop_key -Force | Out-Null
    New-Item $wallpapers_key -Force | Out-Null
    $interval_ms = 600000   # 10 minutes
    # Desktop set tatic wallpaper
    Set-ItemProperty -Path $desktop_key -Name "Wallpaper" -Type String -Value "C:\Users\tb931382\AppData\Roaming\Microsoft\Windows\Themes\TranscodedWallpaper" 
    Set-ItemProperty -Path $desktop_key -Name "WallpaperStyle" -Type String -Value "6"
    Set-ItemProperty -Path $desktop_key -Name "TileWallpaper"  -Type String -Value "0"
    # Desktop set Slideshow interval + shuffle
    Set-ItemProperty -Path $slideshow_key -Name "Interval" -Type DWord -Value $interval_ms
    Set-ItemProperty -Path $slideshow_key -Name "Shuffle"  -Type DWord -Value 1
    
    # Explorer\Wallpapers – slideshow config
    Set-ItemProperty -Path $wallpapers_key -Name "SlideshowEnabled" -Type DWord -Value 1
    Set-ItemProperty -Path $wallpapers_key -Name "BackgroundType"   -Type DWord -Value 2
    Set-ItemProperty -Path $wallpapers_key -Name "SlideshowDirectoryPath" -Type String -Value $folder
    Set-ItemProperty -Path $wallpapers_key -Name "SlideshowTickCount" -Type DWord -Value $interval_ms
    rundll32.exe user32.dll, UpdatePerUserSystemParameters
}

# -- win_clutter --

function win_declutter_all() {
    win_declutter_ui
    win_declutter_home_folders
    win_declutter_osapps
    win_declutter_3_and_4_fingers_gestures
    win_declutter_unused_keyboard_shortcuts
    win_declutter_bell_sounds
    win_declutter_explorer_listing_files
    win_declutter_web_search_and_widgets
    win_declutter_taskbar_startmenu
    win_declutter_xbox
    explorer_restart
}


function win_declutter_ui() {
    log_msg "win_declutter_ui"
    $personalize_key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $accent_key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent"
    $advanced_key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $taskbar_key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings"
    
    # dark enabled and transparent disabled
    Set-ItemProperty -Path $personalize_key -Name "AppsUseLightTheme" -Value 0 -Type Dword -Force 
    Set-ItemProperty -Path $personalize_key -Name "SystemUsesLightTheme" -Value 0 -Type Dword -Force 
    Set-ItemProperty -Path $personalize_key -Name "EnableTransparency" -Value 0 -Type Dword -Force 
    Set-ItemProperty -Path $personalize_key -Name "ColorPrevalence" -Value 0 -Type Dword -Force 
    
    # gray accent color
    $accent_palette = "cc,cc,cc,00,ae,ae,ae,00,92,92,92,00,76,76,76,00,4f,4f,4f,00,37,37,37,00,26,26,26,00,d1,34,38,00"
    $hexified = $accent_palette.Split(',') | ForEach-Object { "0x$_" }
    Set-ItemProperty -Path $accent_key -Name "AccentPalette" -Value ([byte[]]$hexified) -Type Binary
    Set-ItemProperty -Path $accent_key -Name "AccentColor" -Value 0xff000000 -Type Dword -Force
    Set-ItemProperty -Path $accent_key -Name "AccentColorMenu" -Value 0xff767676 -Type Dword -Force
    Set-ItemProperty -Path $accent_key -Name "StartColorMenu" -Value 0xff4f4f4f -Type Dword -Force
    
    # hide desktop icons
    Set-ItemProperty -Path $advanced_key -Name "HideIcons" -Value 1
    New-Item -Path $taskbar_key -Force | Out-Null
    Set-ItemProperty -Path $taskbar_key -Name "TaskbarEndTask" -Value 1 -Force
}

function win_declutter_home_folders() {
    $paths = @(
        "${env:userprofile}\Cookies"
        "${env:userprofile}\Local Settings"
        "${env:userprofile}\My Documents"
        "${env:userprofile}\Start Menu"
        "${env:userprofile}\PrintHood"
        "${env:userprofile}\Recent"
        "${env:userprofile}\SendTo"
        "${env:userprofile}\NetHood"
        "${env:userprofile}\Templates"
    )
    $paths | ForEach-Object { 
        if (Test-Path "$_") {
            Remove-Item $_
        }
    }
}

function win_declutter_osapps() {
    log_msg "win_declutter_osapps"
    winget_uninstall "Mail and Calendar"
    winget_uninstall "MSN Weather"
    winget_uninstall "Microsoft Sticky Notes"
    winget_uninstall "Microsoft Clipchamp"
    winget_uninstall "Microsoft Journal"
    winget_uninstall "Solitaire & Casual Games"
    winget_uninstall "Game Bar"
    winget_uninstall "News"
    winget_uninstall "Windows Maps"
    winget_uninstall "Microsoft People"
    winget_uninstall "Films & TV"
    winget_uninstall "Power Automate"
    winget_uninstall "Dev HOME"
    winget_uninstall 9P6PMZTM93LR # Defender
    winget_uninstall 9WZDNCRD29V9 # Microsoft 365 Copilot
    winget_uninstall 9PDJDJS743XF # Family
    winget_uninstall "Phone Link"
    winget_uninstall "Windows Web Experience Pack"
    winget_uninstall "Windows Sound Recorder"
    winget_uninstall "Cross Device Experience Host"
}

function win_declutter_3_and_4_fingers_gestures() {
    log_msg "win_declutter_3_and_4_fingers_gestures"
    $reg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad"
    Set-ItemProperty -Path $reg -Name "FourFingerDown" -Value 0 -Type Dword
    Set-ItemProperty -Path $reg -Name "FourFingerLeft" -Value 0 -Type Dword
    Set-ItemProperty -Path $reg -Name "FourFingerRight" -Value 0 -Type Dword
    Set-ItemProperty -Path $reg -Name "FourFingerUp" -Value 0 -Type Dword
    Set-ItemProperty -Path $reg -Name "FourFingerTapEnabled" -Value 0 -Type Dword
    Set-ItemProperty -Path $reg -Name "ThreeFingerDown" -Value 0 -Type Dword
    Set-ItemProperty -Path $reg -Name "ThreeFingerLeft" -Value 0 -Type Dword
    Set-ItemProperty -Path $reg -Name "ThreeFingerRight" -Value 0 -Type Dword
    Set-ItemProperty -Path $reg -Name "ThreeFingerTapEnabled" -Value 0 -Type Dword
    Set-ItemProperty -Path $reg -Name "ThreeFingerUp" -Value 0 -Type Dword
}

function win_declutter_unused_keyboard_shortcuts() {
    log_msg "win_declutter_unused_keyboard_shortcuts"
    $advanced_key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $access_key = "HKCU:\Control Panel\Accessibility"
    $toggle_key = "HKCU:\Keyboard Layout\Toggle"
    $igf_key = "HKCU:\Software\Intel\Display\Igfxcui"
    $narrator_key = "HKCU:\Software\Microsoft\Narrator"
    $narrator_cp_key = "HKCU:\Control Panel\Accessibility\Narrator"
    
    # "disable win+v shortcut"
    $value_name = "DisabledHotkeys"
    $key_to_disable = "V"
    $current = (Get-ItemProperty -Path $advanced_key -Name $value_name -ErrorAction SilentlyContinue).$value_name
    $new_value = $current
    if ($null -eq $new_value -or $new_value -notlike "*$key_to_disable*") {
        $new_value = ($new_value | Out-String).Trim() + $key_to_disable
        Set-ItemProperty -Path $advanced_key -Name $value_name -Value $new_value
    }
    
    # "disable AutoRotation shortcuts"
    New-Item -Path $igf_key -Force | Out-Null
    Set-ItemProperty -Path $igf_key -Name "HotKeys" -Value 'Disable'

    # "disable language shortcuts"
    Set-ItemProperty -Path $toggle_key -Name "HotKey" -Value '3' -Type String
    Set-ItemProperty -Path $toggle_key -Name "Language Hotkey" -Value '3' -Type String
    Set-ItemProperty -Path $toggle_key -Name "Layout Hotkey" -Value '3' -Type String

    # "disable acessibility shortcuts"
    New-Item -Path $access_key -Force | Out-Null
    New-Item -Path "$access_key\ToggleKeys" -Force | Out-null
    New-Item -Path "$access_key\StickyKeys" -Force | Out-null
    New-Item -Path "$access_key\Keyboard Response"  -Force | Out-null
    Set-ItemProperty -Path "$access_key\ToggleKeys" -Name "Flags" -Value '58' -Type String
    Set-ItemProperty -Path "$access_key\StickyKeys" -Name "Flags" -Value '26' -Type String
    Set-ItemProperty -Path "$access_key\Keyboard Response" -Name "Flags" -Value '122' -Type String
    New-Item -Path $narrator_key -Force | Out-Null
    Set-ItemProperty -Path $narrator_key -Name "NarratorRunning" -Value 0 -Type DWord
    Set-ItemProperty -Path $narrator_key -Name "StartNarratorHotkey" -Value 0 -Type DWord 
    Set-ItemProperty -Path $narrator_key -Name "Autostart" -Value 0 -Type DWord 
    New-Item -Path $narrator_cp_key -Force | Out-Null
    Set-ItemProperty -Path $narrator_cp_key -Name "WinEnterLaunchEnabled" -Value 0 -Type DWord 
}

function win_declutter_bell_sounds() {
    log_msg "win_declutter_bell_sounds"
    Set-ItemProperty -Path "HKCU:\AppEvents\Schemes\" "(Default)" -Value ".None"
    Get-ChildItem -Path 'HKCU:\AppEvents\Schemes\Apps' | Get-ChildItem | Get-ChildItem | Where-Object { $_.PSChildName -eq '.Current' } | Set-ItemProperty -Name '(Default)' -Value '' 
}

function win_declutter_web_search_and_widgets() {
    log_msg "win_declutter_web_search_and_widgets"
    winget_uninstall 9PC1H9VN18CM # start experiences
}

function win_declutter_explorer_listing_files() {
    log_msg "win_declutter_explorer_listing_files"
    $explorer_key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
    $advanced_key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $shell_key = 'HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell' 
    
    Set-ItemProperty -Path $explorer_key -Name "ShowFrequent" -Value 0 -Type Dword
    Set-ItemProperty -Path $explorer_key -Name "ShowRecent" -Value 0 -Type Dword
    Set-ItemProperty -Path $explorer_key -Name "ShowRecommendations" -Value 0 -Type Dword
    Set-ItemProperty -Path $explorer_key -Name "HideFileExt" -Value 0 -Type Dword
    Set-ItemProperty -Path $explorer_key -Name "DisableGraphRecentItems" -Value 1 -Type Dword
    Set-ItemProperty -Path $advanced_key -Name "ShowAccountBasedInsights" -Value 0 -Type Dword
    Set-ItemProperty -Path $advanced_key -Name "Start_TrackDocs" -Value 0 -Type Dword
    Set-ItemProperty -Path $advanced_key -Name "Start_TrackDocsInJumpLists" -Value 0 -Type Dword
    Set-ItemProperty -Path $advanced_key -Name "ShowRecommendedFiles" -Value 0 -Type Dword
    Set-ItemProperty -Path $advanced_key -Name "LaunchTo" -Value 1 -Type Dword # This PC

    # disable grouping
    # https://answers.microsoft.com/en-us/windows/forum/all/completely-disable-file-grouping-always-everywhere/ac31a227-f585-4b0a-ab2e-a557828eaec5
    Remove-Item -Path "$shell_key\BagMRU"  -Force -ErrorAction SilentlyContinue
}

function win_declutter_taskbar_startmenu() {
    log_msg "win_declutter_taskbar_startmenu"
    $start_key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"
    $advanced_key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $search_key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    $pen_key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PenWorkspace"
    $touch_key = "HKCU:\Software\Microsoft\TabletTip\1.7"
    
    # taskbar
    Set-ItemProperty -Path $advanced_key -Name "ShowTaskViewButton" -Value 0 -Type Dword
    Set-ItemProperty -Path $advanced_key -Name "TaskbarMn" -Value 0 -Type Dword
    Set-ItemProperty -Path $advanced_key -Name "ShowCopilotButton" -Value 0 -Type Dword
    Set-ItemProperty -Path $advanced_key -Name "UseCompactMode" -Value 1 -Type Dword
    Set-ItemProperty -Path $advanced_key -Name "ShowStatusBar" -Value 1 -Type Dword
    Set-ItemProperty -Path $advanced_key -Name "TaskbarAI" -Value 0 -Type Dword
    Set-ItemProperty -Path $advanced_key -Name "TaskbarBadges" -Value 0 -Type Dword
    Set-ItemProperty -Path $advanced_key -Name "TaskbarAnimations" -Value 0 -Type Dword
    Set-ItemProperty -Path $pen_key -Name "PenWorkspaceButtonDesiredVisibility" -Type DWord -Value 0 -Force | Out-Null
    Set-ItemProperty -Path $touch_key -Name "TipbandDesiredVisibility" -Type DWord -Value 0 -Force | Out-Null

    # taskbar multitasking
    Set-ItemProperty -Path $advanced_key -Name MMTaskbarEnabled -Value 0 -Type DWord
    Set-ItemProperty -Path $advanced_key -Name MMTaskbarMode -Value 2 -Type DWord
    Set-ItemProperty -Path $advanced_key -Name "MultiTaskingAltTabFilter" -Value 3 -Type Dword
    Set-ItemProperty -Path $advanced_key -Name "SnapAssist" -Value 0 -Type Dword
    
    # taskbar search
    $search_key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    Set-ItemProperty -Path $search_key -Name "SearchboxTaskbarMode" -Type DWord -Value 0 -Force | Out-Null
    Set-ItemProperty -Path $search_key -Name "SearchboxTaskbarModeCache" -Type DWord -Value 0 -Force | Out-Null
    
    # startmenu
    Set-ItemProperty -Path $start_key -Name "ShowRecentList" -Value 0 -Type DWord
    Set-ItemProperty -Path $advanced_key -Name "Start_TrackProgs" -Value 0 -Type DWord
    Set-ItemProperty -Path $advanced_key -Name "Start_TrackDocs" -Value 0 -Type DWord
    Set-ItemProperty -Path $advanced_key -Name "Start_IrisRecommendations" -Value 0 -Type DWord
    Set-ItemProperty -Path $advanced_key -Name "Start_AccountNotifications" -Type DWord -Value 0
}

function win_declutter_xbox() {
    log_msg "win_declutter_xbox"
    $game_dvr_key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
    $game_store_key = "HKCU:\System\GameConfigStore"

    Set-ItemProperty -Path $game_dvr_key -Name "AppCaptureEnabled" -Value 0 -Type Dword
    Set-ItemProperty -Path $game_dvr_key -Name "HistoricalCaptureEnabled" -Value 0 -Type Dword
    Set-ItemProperty -Path $game_store_key -Name "GameDVR_Enabled" -Value 0 -Type Dword
    winget_uninstall 9MV0B5HZVK9Z
    winget_uninstall "Xbox TCUI" 
    winget_uninstall "Xbox Identity Provider" 
    winget_uninstall "Microsoft Edge Game Assist" 
    winget_uninstall Microsoft.XboxSpeechToTextOverlay_8wekyb3d8bbwe
}