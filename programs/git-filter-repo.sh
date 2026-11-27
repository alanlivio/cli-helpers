_git_filter_repo_push() {
    log_msg "git-filter-repo successfully finished"
    if [[ -z "${GIT_LAST_ORIGIN:-}" ]]; then
        log_msg "var GIT_LAST_ORIGIN not defined (maybe this is a new shell after editing). please do push manually or restart repo."
        return 0
    fi
    log_msg "Is it to force push branch ${GIT_LAST_BRANCH:-} to origin $GIT_LAST_ORIGIN (y/n)? "
    local answer
    answer="$(while ! head -c 1 | grep -i '[ny]'; do true; done)"
    if echo "$answer" | grep -iq "^y"; then
        git remote add origin "$GIT_LAST_ORIGIN"
        git push --set-upstream origin "${GIT_LAST_BRANCH:-}" --force
    fi
}

_git_filter_repo_save_origin_and_branch() {
    local origin_url
    origin_url="$(git remote get-url origin 2>/dev/null || true)"
    if [[ -n "$origin_url" ]]; then
        GIT_LAST_ORIGIN="$origin_url"
        GIT_LAST_BRANCH="$(git branch --show-current)"
    fi
}

git_filter_repo_messages_to_lower_case() {
    _git_filter_repo_save_origin_and_branch
    if git-filter-repo --message-callback "'return message.lower()'" --force; then
        _git_filter_repo_push
    fi
}

git_filter_repo_messages_remove_str() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <str>"
        return 1
    fi
    _git_filter_repo_save_origin_and_branch
    if git-filter-repo --message-callback "'return message.replace(b\"$1\", b\"\")'" --force; then
        _git_filter_repo_push
    fi
}

git_filter_repo_user_rename_to_current() {
    log_msg "Do want use the user.email=$(git config user.email)(y/n)? "
    local answer
    answer="$(while ! head -c 1 | grep -i '[ny]'; do true; done)"
    if ! echo "$answer" | grep -iq "^y"; then
        return 0
    fi
    _git_filter_repo_save_origin_and_branch
    local new_name new_email
    new_name="$(git config user.name)"
    new_email="$(git config user.email)"
    if git-filter-repo --name-callback "'return b\"$new_name\"'" --email-callback "'return b\"$new_email\"'" --force; then
        _git_filter_repo_push
    fi
}

git_filter_repo_user_rename_as_mailmap() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <mailmap>"
        return 1
    fi
    _git_filter_repo_save_origin_and_branch
    if git-filter-repo --mailmap "$1" --force; then
        _git_filter_repo_push
    fi
}

git_filter_repo_delete_file_bigger_than_50M() {
    _git_filter_repo_save_origin_and_branch
    if git-filter-repo --strip-blobs-bigger-than 50M --force; then
        _git_filter_repo_push
    fi
}

git_filter_repo_delete_file_bigger_than_1M() {
    _git_filter_repo_save_origin_and_branch
    if git-filter-repo --strip-blobs-bigger-than 1M --force; then
        _git_filter_repo_push
    fi
}

git_filter_repo_delete_file() {
    if [[ -z "${1:-}" ]]; then
        log_error "Usage: ${FUNCNAME[0]} <filename>"
        return 1
    fi
    _git_filter_repo_save_origin_and_branch
    if git-filter-repo --use-base-name --invert-paths --path "$1" --force; then
        _git_filter_repo_push
    fi
}
