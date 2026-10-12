function git_clone_or_pull() {
    param(
        [string]$url, 
        [string]$basedir, 
        [string]$email
    )
    if ($PSBoundParameters.Keys.Count -lt 2) { 
        log_error "Usage: git_clone_or_pull <url> <basedir> [<email>]. Use <email> to differ from ~/.gitconfig email."; return 
    }
    $dir = Join-Path $basedir (Split-Path $url -Leaf)
    if (Test-Path $dir) {
        Push-Location $dir
        log_msg "git pull at $dir"
        git pull -q
        Pop-Location
    } else {
        if (-not (Test-Path $basedir)) {
            New-Item -Path $basedir -ItemType Directory -Force
        }
        log_msg "git clone $url at $dir"
        git clone $url $dir
    }
    if (-not ([string]::IsNullOrEmpty($email))) {
        Push-Location $dir
        git config user.email "$email"
        Pop-Location
    }
}

function git_pull_recursive {
    param([string]$folder)
    if ($PSBoundParameters.Keys.Count -lt 1) {
        log_error "Usage: git_pull_recursive <folder>"; return $false
    }
    if (-not (Test-Path $folder)) { return $false; }
    $pulled = $false
    @(Get-Item -LiteralPath $folder; Get-ChildItem -LiteralPath $folder -Directory) | ForEach-Object {
        $sub = $_.FullName
        if (Test-Path "$sub/.git") {
            Push-Location $sub
            log_msg "git pull at $($sub.Replace('\', '/'))"
            $before = (git rev-parse HEAD 2>$null)
            $null = git pull -q
            $after = (git rev-parse HEAD 2>$null)
            if ($before -and $after -and ($before -ne $after)) {
                $pulled = $true
            }
            Pop-Location
        }
    }
    return $pulled
}

function git_ignore_template_list {
    (Invoke-WebRequest -Uri "https://www.toptal.com/developers/gitignore/api/list" -UseBasicParsing).Content
}

function _git_ignore_template_prepend {
    param ( [Parameter(Mandatory = $true)] [string]$content )
    if (-not $content) { return }
    if (Test-Path .gitignore) {
        $existing = Get-Content -Path .gitignore -Raw
        if ($existing) {
            Set-Content -Path .gitignore -Value "$($content.TrimEnd())`r`n`r`n$existing"
            return
        }
    }
    Set-Content -Path .gitignore -Value $content
}

function git_ignore_template_add {
    param ( [Parameter(Mandatory = $true, HelpMessage = "Usage: git_ignore_template_add <templates,..>")] [string]$templates )
    $content = (Invoke-WebRequest -Uri "https://www.toptal.com/developers/gitignore/api/$templates" -UseBasicParsing).Content
    _git_ignore_template_prepend $content
}

function git_ignore_template_add_vscode {
    $content = (Invoke-WebRequest -Uri "https://www.toptal.com/developers/gitignore/api/visualstudiocode" -UseBasicParsing).Content
    _git_ignore_template_prepend $content
}

function git_ignore_template_add_common {
    $content = (Invoke-WebRequest -Uri "https://www.toptal.com/developers/gitignore/api/visualstudiocode,python,node,c++,windows,macos" -UseBasicParsing).Content
    _git_ignore_template_prepend $content
}

function git_branch_remove_local_and_remote {
    param ( [Parameter(Mandatory = $true)] [string]$branchname )
    git branch -d $branchname
    git push origin --delete $branchname
}

function git_push_after_amend_all {
    git commit -a --amend --no-edit
    git push --force
}

function git_formated_patch_n_last_commits {
    param ( [Parameter(Mandatory = $true)] [int]$number_of_last_commits )
    git format-patch HEAD~$number_of_last_commits
}

function git_formated_patch_apply {
    param ( [Parameter(Mandatory = $true)] [string[]]$args )
    foreach ($file in $args) {
        git am $file
    }
}

function git_tag_move_to_head_and_push {
    param ( [Parameter(Mandatory = $true)] [string]$tagname )
    git tag -d $tagname
    git tag $tagname
    git push --force --tags
}

Export-ModuleMember -Function *
