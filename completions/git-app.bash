# bash completion for rk / git-app (rk-cli-utils)
# Works with bash 3.2+ and does not require the bash-completion package.

_gha_actions="clone add commit fetch pull push check session token revoke config help version"
_gha_global_opts="--profile --config --dry-run --verbose --quiet --help --version"

_gha_profiles() {
    if command -v git-app >/dev/null 2>&1; then
        git-app config profiles 2>/dev/null
    else
        rk git-app config profiles 2>/dev/null
    fi
}

_gha_remotes() {
    git remote 2>/dev/null
}

_gha_branches() {
    git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null
}

# Complete the words of a git-app command line.
# $1 = index in COMP_WORDS of the word after "git-app" (or after "rk git-app")
_gha_complete_words() {
    local start="$1" cur prev i w action="" skip=0 positional=0
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD - 1]}"

    # Value of a global option.
    case "$prev" in
        --profile)
            COMPREPLY=($(compgen -W "$(_gha_profiles)" -- "$cur"))
            return 0 ;;
        --config)
            COMPREPLY=($(compgen -f -- "$cur"))
            return 0 ;;
    esac

    # Find the action and count positionals after it.
    for ((i = start; i < COMP_CWORD; i++)); do
        w="${COMP_WORDS[i]}"
        if [[ -z "$action" ]]; then
            case "$w" in
                --profile | --config) skip=1 ;;
                -*) ;;
                *) if (( skip )); then skip=0; else action="$w"; fi ;;
            esac
        elif [[ "$w" != -* ]]; then
            positional=$((positional + 1))
        fi
    done

    if [[ -z "$action" ]]; then
        if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "$_gha_global_opts" -- "$cur"))
        else
            COMPREPLY=($(compgen -W "$_gha_actions" -- "$cur"))
        fi
        return 0
    fi

    case "$action" in
        clone)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--depth --branch --single-branch --no-single-branch --recurse-submodules --shallow-submodules --filter --origin --no-checkout --bare --mirror --sparse --no-tags --tags --jobs --quiet --verbose --progress" -- "$cur"))
            elif [[ "$positional" -ge 1 ]]; then
                COMPREPLY=($(compgen -d -- "$cur"))
            fi ;;
        fetch)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--all --prune --prune-tags --tags --no-tags --depth --deepen --unshallow --force --jobs --dry-run --quiet --verbose --progress --recurse-submodules --set-upstream --filter" -- "$cur"))
            elif [[ "$positional" -eq 0 ]]; then
                COMPREPLY=($(compgen -W "$(_gha_remotes)" -- "$cur"))
            else
                COMPREPLY=($(compgen -W "$(_gha_branches)" -- "$cur"))
            fi ;;
        pull)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--rebase --no-rebase --ff-only --no-ff --ff --squash --autostash --no-autostash --prune --tags --no-tags --depth --unshallow --force --quiet --verbose --progress --strategy --strategy-option --commit --no-commit --verify-signatures" -- "$cur"))
            elif [[ "$positional" -eq 0 ]]; then
                COMPREPLY=($(compgen -W "$(_gha_remotes)" -- "$cur"))
            else
                COMPREPLY=($(compgen -W "$(_gha_branches)" -- "$cur"))
            fi ;;
        push)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--force-with-lease --force --tags --follow-tags --all --delete --set-upstream --dry-run --atomic --prune --no-verify --push-option --signed --quiet --verbose --progress" -- "$cur"))
            elif [[ "$positional" -eq 0 ]]; then
                COMPREPLY=($(compgen -W "$(_gha_remotes)" -- "$cur"))
            else
                COMPREPLY=($(compgen -W "$(_gha_branches)" -- "$cur"))
            fi ;;
        add)
            if [[ "$cur" != -* ]]; then COMPREPLY=($(compgen -f -- "$cur")); fi ;;
        commit)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "-m --message -a --all --amend --no-verify --signoff --allow-empty --dry-run" -- "$cur"))
            fi ;;
        check)
            if [[ "$positional" -eq 0 && "$cur" != -* ]]; then
                COMPREPLY=($(compgen -W "$(_gha_remotes)" -- "$cur"))
            fi ;;
        session | token)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--write --repo --" -- "$cur"))
            elif [[ "$prev" == --repo ]]; then
                COMPREPLY=($(compgen -W "$(_gha_remotes)" -- "$cur"))
            fi ;;
        config)
            if [[ "$positional" -eq 0 ]]; then
                COMPREPLY=($(compgen -W "show init profiles" -- "$cur"))
            fi ;;
    esac
    return 0
}

_git_app_completion() {
    COMPREPLY=()
    _gha_complete_words 1
}

_rk_completion() {
    COMPREPLY=()
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$COMP_CWORD" -eq 1 ]]; then
        COMPREPLY=($(compgen -W "setup-ssh slack-send get-slack-id git-app --help --version" -- "$cur"))
        return 0
    fi
    case "${COMP_WORDS[1]}" in
        git-app) _gha_complete_words 2 ;;
        setup-ssh) COMPREPLY=($(compgen -W "--email --user --key-file --host" -- "$cur")) ;;
        slack-send) COMPREPLY=($(compgen -W "--token --channel --message --color" -- "$cur")) ;;
        get-slack-id) COMPREPLY=($(compgen -W "--email --token" -- "$cur")) ;;
    esac
    return 0
}

complete -F _git_app_completion git-app
complete -F _rk_completion rk
