#!/usr/bin/env bash
set -euo pipefail

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
PROXY_MAX_REQUESTS_AUTONOMOUS="${PROXY_MAX_REQUESTS_AUTONOMOUS:-300}"
export AGENT_USER=agent
hardened_validate_common_config
hardened_require_command docker

usage() {
    cat <<'EOF_USAGE'
Usage:
  ./enter-running.sh
  ./enter-running.sh CONTAINER_ID_OR_NAME

With no argument, enters the only running container created from this package's
agent image. If more than one is running, the script lists them and asks you to
supply a container ID or name.
EOF_USAGE
}

(($# <= 1)) || { usage >&2; exit 2; }
case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
    MATCHES="$(
        docker ps \
            --filter "ancestor=$IMAGE_NAME" \
            --format '{{.ID}}\t{{.Names}}\t{{.Status}}'
    )"
    COUNT="$(printf '%s\n' "$MATCHES" | awk 'NF { count++ } END { print count + 0 }')"
    if [[ "$COUNT" == 0 ]]; then
        hardened_die "no running $IMAGE_NAME container was found; use ./shell.sh for a new shell"
    fi
    if [[ "$COUNT" != 1 ]]; then
        printf 'More than one agent container is running:\n%s\n' "$MATCHES" >&2
        hardened_die "rerun as ./enter-running.sh CONTAINER_ID_OR_NAME"
    fi
    TARGET="$(printf '%s\n' "$MATCHES" | awk 'NF { print $1; exit }')"
fi

RUNNING_IMAGE="$(docker inspect --format '{{.Config.Image}}' "$TARGET" 2>/dev/null || true)"
[[ "$RUNNING_IMAGE" == "$IMAGE_NAME" ]] || \
    hardened_die "$TARGET is not a running $IMAGE_NAME container"

hardened_warn "this shell is outside the coding agent's command sandbox and inherits the running container's mounts and network"
hardened_warn "subscription state or a Stata license may be mounted; do not run untrusted commands"
exec docker exec -it "$TARGET" bash --noprofile --norc
