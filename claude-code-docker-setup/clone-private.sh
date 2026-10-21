#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
hardened_load_config "$SCRIPT_DIR/config.env"
IMAGE_NAME="${IMAGE_NAME:-agents-research}"
PROXY_IMAGE_NAME="${PROXY_IMAGE_NAME:-agents-research-proxy}"
AGENT_VERSION="${AGENT_VERSION:-0.144.4}"
STATA_IMAGE="${STATA_IMAGE:-dataeditors/stata19-se-i-python@sha256:1691fce6250011bef77cb64df58316bc72ed82b9791456e4b804832d9bfd747d}"
STATA_EDITION="${STATA_EDITION:-se}"
GIT_USER_NAME="${GIT_USER_NAME:-Research Agent}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-research-agent@users.noreply.github.com}"
MEMORY_LIMIT="${MEMORY_LIMIT:-16g}"
CPU_LIMIT="${CPU_LIMIT:-4}"
PIDS_LIMIT="${PIDS_LIMIT:-512}"
SHM_SIZE="${SHM_SIZE:-1g}"
PLATFORM="${PLATFORM:-linux/amd64}"
PROXY_MAX_REQUESTS_INTERACTIVE="${PROXY_MAX_REQUESTS_INTERACTIVE:-1000}"
PROXY_MAX_REQUESTS_AUTONOMOUS="${PROXY_MAX_REQUESTS_AUTONOMOUS:-2000}"
export AGENT_USER=agent
hardened_validate_common_config
    
    
(($# >= 1 && $# <= 2)) || hardened_die "usage: ./clone-private.sh <https-github-url> [branch]"
URL="$1"
BRANCH="${2:-}"
hardened_is_public_github_url "$URL" || hardened_die "only HTTPS github.com repository URLs are accepted"
hardened_validate_branch "$BRANCH"
hardened_require_command docker

GH_DIR="$SCRIPT_DIR/auth/gh"
hardened_reject_symlink_components "$GH_DIR" "GitHub credential directory"
[[ -d "$GH_DIR" && ! -L "$GH_DIR" ]] || hardened_die "GitHub credential directory is unsafe"
hardened_dir_has_files "$GH_DIR" || hardened_die "GitHub authentication is missing; run ./authenticate-github.sh"
hardened_ensure_private_dir "$SCRIPT_DIR/worktrees"

slug="$(hardened_repo_slug "$URL")"
leaf="${slug}-$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM}"
destination="$SCRIPT_DIR/worktrees/$leaf"
mkdir -m 700 -- "$destination"

hardened_resolve_host_identity
uid="$HARDENED_HOST_UID"
gid="$HARDENED_HOST_GID"
if [[ "$(id -u)" == 0 ]]; then
    chown "$uid:$gid" "$destination"
fi

# The token-bearing clone helper sees only one empty destination. It cannot read
# or modify any prior checkout under worktrees/.
if ! docker run --rm \
    --platform "$PLATFORM" \
    --user "$uid:$gid" \
    --init \
    --read-only \
    --cap-drop=ALL \
    --security-opt=no-new-privileges:true \
    --pids-limit 128 \
    --memory 1g \
    --cpus 1 \
    --tmpfs "/tmp:rw,exec,nosuid,nodev,size=512m,uid=$uid,gid=$gid" \
    --tmpfs "/home/helper:rw,nosuid,nodev,size=64m,uid=$uid,gid=$gid" \
    --mount "type=bind,src=$GH_DIR,dst=/gh,readonly" \
    --mount "type=bind,src=$destination,dst=/worktree" \
    -e HOME=/home/helper \
    -e GH_CONFIG_DIR=/gh \
    --entrypoint /opt/agent/github-helper \
    "$IMAGE_NAME" clone-private "$URL" /worktree "$BRANCH"; then
    rm -rf -- "$destination"
    hardened_die "private repository clone failed"
fi

printf 'Private repository cloned to:\n%s\n' "$destination"
printf 'Run the agent against that local path with ./go; default runs mount the GitHub credential read-only.\n'
