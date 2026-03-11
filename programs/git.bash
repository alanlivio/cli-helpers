function git_clone_to() {
    : ${2?"Usage: git_clone_to <url> <basedir> [<email>]. Use <email> to differ from ~/.gitconfig email."}
    local url=$1
    local basedir=$2
    local email=$3
    local dir=$basedir/${1##*/}
    if [[ -d $dir ]]; then
        (
            cd "$dirb" 
            log_msg "git pull at $dir"
            git pull -q
        )
    else
        if [[ ! -d $basedir ]]; then mkdir -p $basedir; fi
        log_msg "git clone $url at $dir"
        git clone $url $dir

    fi
    if [[ -n $email ]]; then
    (
        cd $dir
        git config user.email "$email"
    )
    fi
}

function git_pull_recursive() {
    : ${1?"Usage: git_pull_recursive <folder>"}
    local folder=$1
    if [[ ! -d $folder ]]; then return; fi;
    for sub in "$folder" "$folder"/*; do
        if [[ -d "$sub/.git" ]]; then
            (
                cd "$sub" 
                log_msg "git pull at $sub"
                git pull -q
            )
        fi
    done
}

function git_gitignore_types_list() {
    curl -L -s "https://www.gitignore.io/api/list"
}

function git_gitignore_types_add() {
    : ${1?"Usage: ${FUNCNAME[0]} <type1,type2..>"}
    curl -L -s "https://www.gitignore.io/api/$1" >>.gitignore
}

function git_gitignore_types_add_vscode {
    curl -L -s "https://www.gitignore.io/api/visualstudiocode" >>.gitignore
}

function git_branch_remove_local_and_remote() {
    : ${1?"Usage: ${FUNCNAME[0]} <branch-name>"}
    git branch -d $1
    git push origin --delete $1
}

function git_push_after_amend_all() {
    git commit -a --amend --no-edit
    git push --force
}

function git_formated_patch_n_last_commits() {
    : ${1?"Usage: ${FUNCNAME[0]} <number_of_last_commits>"}
    git format-patch HEAD~$1
}

function git_formated_patch_apply() {
    git am <"$@"
}

function git_tag_move_to_head_and_push() {
    git tag -d $1
    git tag $1
    git push --force --tags
}

function git_branch_all_remotes_checkout_and_reset() {
    local CURRENT=$(git branch --show-current)
    git fetch -p origin
    git branch -r | grep -v '\->' | while read -r remote; do
        git reset --hard
        git clean -ndf
        log_msg "updating ${remote#origin/}"
        git checkout "${remote#origin/}"
        if test $? != 0; then
            log_error "cannot goes to ${remote#origin/} because there are local changes" && return 1
        fi
        git pull --all
        if test $? != 0; then
            log_error "cannot pull ${remote#origin/} because there are local changes" && return 1
        fi
    done
    log_msg "returning to branch $CURRENT"
    git checkout $CURRENT
}