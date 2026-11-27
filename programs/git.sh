git_clone_or_pull() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: git_clone_or_pull <url> <basedir> [<email>]. Use <email> to differ from ~/.gitconfig email."
        return 1
    fi
    local url="$1"
    local basedir="$2"
    local email="${3:-}"
    local repo_name="${url##*/}"
    repo_name="${repo_name%.git}"
    local dir="$basedir/$repo_name"
    if [[ -d "$dir" ]]; then
        log_msg "git pull at $dir"
        git -C "$dir" pull -q
    else
        [[ ! -d "$basedir" ]] && mkdir -p "$basedir"
        log_msg "git clone $url at $dir"
        git clone "$url" "$dir"
    fi
    if [[ -n "$email" ]]; then
        git -C "$dir" config user.email "$email"
    fi
}

git_pull_recursive() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: git_pull_recursive <folder>"
        return 1
    fi
    local folder="$1"
    if [[ ! -d "$folder" ]]; then
        return 1
    fi
    local pulled=1
    local sub before after
    for sub in "$folder" "$folder"/*; do
        if [[ -d "$sub/.git" ]]; then
            log_msg "git pull at $sub"
            before="$(git -C "$sub" rev-parse HEAD 2>/dev/null || true)"
            git -C "$sub" pull -q
            after="$(git -C "$sub" rev-parse HEAD 2>/dev/null || true)"
            if [[ -n "$before" && -n "$after" && "$before" != "$after" ]]; then
                pulled=0
            fi
        fi
    done
    return "$pulled"
}

git_ignore_template_list() {
    curl -L -s "https://www.gitignore.io/api/list"
}

_git_ignore_template_prepend() {
    local content="$1"
    if [[ -z "$content" ]]; then
        return 1
    fi
    if [[ -s .gitignore ]]; then
        local existing
        existing="$(cat .gitignore)"
        printf '%s\n\n%s\n' "$content" "$existing" >.gitignore
    else
        printf '%s\n' "$content" >.gitignore
    fi
}

git_ignore_template_add() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <template1,template2..>"
        return 1
    fi
    local content
    content="$(curl -L -s "https://www.gitignore.io/api/$1")"
    _git_ignore_template_prepend "$content"
}

git_ignore_template_add_vscode() {
    local content
    content="$(curl -L -s "https://www.gitignore.io/api/visualstudiocode")"
    _git_ignore_template_prepend "$content"
}

git_ignore_template_add_common() {
    local content
    content="$(curl -L -s "https://www.gitignore.io/api/visualstudiocode,python,node,c++,windows,macos")"
    _git_ignore_template_prepend "$content"
}

git_branch_remove_local_and_remote() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <branch-name>"
        return 1
    fi
    git branch -d "$1"
    git push origin --delete "$1"
}

git_branch_merge_into_main() {
    local branch="${1:-dev}"
    git checkout main &&
        git pull origin main &&
        git merge "$branch" &&
        git push origin main &&
        git_branch_remove_local_and_remote "$branch"
}

git_push_after_amend_all() {
    git commit -a --amend --no-edit
    git push --force
}

git_formated_patch_n_last_commits() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <number_of_last_commits>"
        return 1
    fi
    git format-patch "HEAD~$1"
}

git_formated_patch_apply() {
    if [[ $# -lt 1 ]]; then
        log_error "Usage: ${FUNCNAME[0]} <patch-file> ..."
        return 1
    fi
    local file
    for file in "$@"; do
        git am <"$file"
    done
}

git_tag_move_to_head_and_push() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <tag>"
        return 1
    fi
    git tag -d "$1"
    git tag "$1"
    git push --force --tags
}

git_branch_all_remotes_checkout_and_reset() {
    local current_branch
    current_branch="$(git branch --show-current)"
    git fetch -p origin
    local remote
    while read -r remote; do
        [[ -z "$remote" ]] && continue
        git reset --hard
        git clean -ndf
        log_msg "updating ${remote#origin/}"
        if ! git checkout "${remote#origin/}"; then
            log_error "cannot checkout ${remote#origin/} because there are local changes"
            return 1
        fi
        if ! git pull --all; then
            log_error "cannot pull ${remote#origin/} because there are local changes"
            return 1
        fi
    done < <(git branch -r | grep -v '\->')
    log_msg "returning to branch $current_branch"
    git checkout "$current_branch"
}
