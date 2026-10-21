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

GH_DIR="$SCRIPT_DIR/auth/gh"
hardened_ensure_private_dir "$SCRIPT_DIR/auth"
hardened_ensure_private_dir "$GH_DIR"
hardened_require_command docker
hardened_resolve_host_identity
uid="$HARDENED_HOST_UID"
gid="$HARDENED_HOST_GID"

run_gh() {
    local writable="$1" interactive="$2"
    shift 2
    local mount="type=bind,src=$GH_DIR,dst=/gh"
    local -a docker_args=(run --rm)
    [[ "$writable" == 1 ]] || mount+=",readonly"
    [[ "$interactive" == 1 ]] && docker_args+=(-it)
    docker "${docker_args[@]}" \
        --platform "$PLATFORM" \
        --user "$uid:$gid" \
        --init \
        --read-only \
        --cap-drop=ALL \
        --security-opt=no-new-privileges:true \
        --pids-limit 128 \
        --memory 1g \
        --cpus 1 \
        --tmpfs "/tmp:rw,exec,nosuid,nodev,size=128m,uid=$uid,gid=$gid" \
        --tmpfs "/home/helper:rw,nosuid,nodev,size=64m,uid=$uid,gid=$gid" \
        --mount "$mount" \
        -e HOME=/home/helper \
        -e GH_CONFIG_DIR=/gh \
        --entrypoint gh \
        "$IMAGE_NAME" \
        "$@"
}

case "${1:-login}" in
    login)
        (($# <= 1)) || hardened_die "usage: ./authenticate-github.sh login"
        run_gh 1 1 auth login --hostname github.com --web --git-protocol https
        ;;
    status)
        (($# <= 1)) || hardened_die "usage: ./authenticate-github.sh status"
        run_gh 0 0 auth status --hostname github.com
        ;;
    logout)
        (($# <= 1)) || hardened_die "usage: ./authenticate-github.sh logout"
        find "$GH_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
        printf 'Removed GitHub CLI credentials.\n'
        ;;
    *)
        hardened_die "usage: ./authenticate-github.sh [login|status|logout]"
        ;;
esac
