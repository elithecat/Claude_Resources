#!/usr/bin/env bash
set -euo pipefail
umask 077

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

validate_url() {
    [[ "$1" =~ ^https://github[.]com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+([.]git)?/?$ ]] || die "only HTTPS github.com repository URLs are accepted"
}

validate_branch() {
    [[ -n "$1" ]] || return 0
    git check-ref-format --branch "$1" >/dev/null 2>&1 || die "invalid Git branch name"
}

validate_destination() {
    [[ "$1" == /worktree ]] || die "invalid worktree destination"
    [[ -d "$1" && ! -L "$1" ]] || die "worktree destination is not a real directory"
    if find "$1" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
        die "worktree destination is not empty"
    fi
}

git_environment() {
    export GIT_CONFIG_NOSYSTEM=1
    export GIT_CONFIG_GLOBAL=/dev/null
    export GIT_TERMINAL_PROMPT=0
    export GIT_LFS_SKIP_SMUDGE=1
    export SSH_ASKPASS=/bin/false
}

install_askpass() {
    local token
    [[ -d /gh ]] || die "GitHub credential directory is not mounted"
    export GH_CONFIG_DIR=/gh
    token="$(gh auth token)" || die "GitHub CLI is not authenticated"
    [[ -n "$token" && "$token" != *$'\n'* && "$token" != *$'\r'* ]] || die "GitHub token is malformed"
    export GITHUB_TOKEN_INTERNAL="$token"
    cat > /tmp/github-askpass <<'EOF_ASKPASS'
#!/usr/bin/env bash
case "${1:-}" in
    *Username*) printf '%s\n' 'x-access-token' ;;
    *Password*) printf '%s\n' "${GITHUB_TOKEN_INTERNAL:?}" ;;
    *) printf '\n' ;;
esac
EOF_ASKPASS
    chmod 0700 /tmp/github-askpass
    export GIT_ASKPASS=/tmp/github-askpass
}

clone_repo() {
    local url="$1" destination="$2" branch="$3" private="$4"
    validate_url "$url"
    validate_destination "$destination"
    validate_branch "$branch"
    git_environment
    if [[ "$private" == 1 ]]; then
        install_askpass
    else
        export GIT_ASKPASS=/bin/false
    fi

    local -a args=(clone --no-tags --no-recurse-submodules)
    if [[ -n "$branch" ]]; then
        args+=(--branch "$branch" --single-branch)
    fi
    args+=(-- "$url" "$destination")

    git \
        -c core.hooksPath=/dev/null \
        -c core.fsmonitor=false \
        -c credential.helper= \
        -c protocol.file.allow=never \
        -c protocol.ext.allow=never \
        "${args[@]}"
}

prepare_publish_bundle() {
    [[ -d /workspace ]] || die "workspace is not mounted"
    [[ -d /handoff ]] || die "handoff directory is not mounted"
    [[ ! -e /handoff/publish.bundle ]] || die "handoff bundle already exists"
    git_environment

    # This stage deliberately receives neither a GitHub token nor general
    # network access. Project-local Git configuration can therefore affect only
    # this disposable, credential-free container. The token-bearing stage sees
    # only the resulting bundle, never the project tree or its .git/config.
    git -C /workspace \
        -c core.hooksPath=/dev/null \
        -c core.fsmonitor=false \
        -c credential.helper= \
        -c protocol.file.allow=never \
        -c protocol.ext.allow=never \
        bundle create /handoff/publish.bundle HEAD
    [[ -f /handoff/publish.bundle && ! -L /handoff/publish.bundle && -s /handoff/publish.bundle ]] || \
        die "Git bundle was not created safely"
}

publish_bundle() {
    local url="$1" branch="$2" commit
    validate_url "$url"
    validate_branch "$branch"
    [[ -f /handoff/publish.bundle && ! -L /handoff/publish.bundle ]] || \
        die "publish bundle is missing or unsafe"
    if find /workspace -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .; then
        die "token-bearing publisher must not receive project files"
    fi
    git_environment
    install_askpass

    git init --bare /tmp/publish.git >/dev/null
    git --git-dir=/tmp/publish.git \
        -c core.hooksPath=/dev/null \
        -c core.fsmonitor=false \
        -c credential.helper= \
        -c protocol.file.allow=always \
        -c protocol.ext.allow=never \
        fetch --no-tags --no-write-fetch-head /handoff/publish.bundle \
        HEAD:refs/hardened/publish
    commit="$(git --git-dir=/tmp/publish.git rev-parse --verify 'refs/hardened/publish^{commit}')"

    git --git-dir=/tmp/publish.git \
        -c core.hooksPath=/dev/null \
        -c core.fsmonitor=false \
        -c credential.helper= \
        -c protocol.file.allow=never \
        -c protocol.ext.allow=never \
        push --no-verify --porcelain "$url" "$commit:refs/heads/$branch"
}

case "${1:-}" in
    clone-public)
        (($# == 4)) || die "clone-public requires URL, destination, and optional branch value"
        clone_repo "$2" "$3" "$4" 0
        ;;
    clone-private)
        (($# == 4)) || die "clone-private requires URL, destination, and optional branch value"
        clone_repo "$2" "$3" "$4" 1
        ;;
    prepare-publish)
        (($# == 1)) || die "prepare-publish takes no arguments"
        prepare_publish_bundle
        ;;
    publish-bundle)
        (($# == 3)) || die "publish-bundle requires URL and remote branch"
        publish_bundle "$2" "$3"
        ;;
    *) die "unknown GitHub helper operation" ;;
esac
