function win_ps_setup_unix_alias() {
    # Use C:\WINDOWS\system32\curl.exe
    Set-Alias -Name curl -Value curl.exe -Scope Global -Option AllScope -Force
    # winget install Microsoft.Coreutils
    foreach ($cmd in @('ls', 'cp', 'echo', 'pwd', 'mv', 'cat', 'rm', 'sort')) {
        Set-Alias -Name $cmd -Value "$cmd.exe" -Scope Global -Option AllScope -Force
    }
}

function du_folder_list_sorted_by_size {
    du.exe -ahd 1 | sort.exe -h
}
