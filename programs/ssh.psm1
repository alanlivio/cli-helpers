function ssh_send_to_pub_key_to_remote {
    param([string]$server)
    if ($PSBoundParameters.Keys.Count -lt 1) { log_error "Usage: $($MyInvocation.MyCommand.Name) user@host"; return }
    $publicKeyPath = Join-Path $env:userprofile ".ssh\id_rsa.pub"
    (Get-Content $publicKeyPath -Raw) -replace "`r`n", "`n"  | ssh "$server" "sh -c 'cat - >> ~/.ssh/authorized_keys'"
}

function ssh_send_priv_key_to_remote {
    param([string]$server)
    if ($PSBoundParameters.Keys.Count -lt 1) { log_error "Usage: $($MyInvocation.MyCommand.Name) user@host"; return }
    $privateKeyPath = Join-Path $env:userprofile ".ssh\id_rsa"
    (Get-Content $privateKeyPath -Raw) -replace "`r`n", "`n" | ssh "$server" "sh -c 'cat - > ~/.ssh/id_rsa;chmod 600 ~/.ssh/id_rsa'"
}

Export-ModuleMember -Function *
