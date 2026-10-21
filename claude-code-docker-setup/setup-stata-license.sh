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
    
    
ALLOW_NETWORK=0
case "${1:-}" in
    '') ;;
    --allow-network) ALLOW_NETWORK=1 ;;
    -h|--help)
        printf 'usage: ./setup-stata-license.sh [--allow-network]\n'
        exit 0
        ;;
    *) hardened_die "usage: ./setup-stata-license.sh [--allow-network]" ;;
esac

hardened_require_command docker
hardened_ensure_private_dir "$SCRIPT_DIR/auth"
RUN_TMP="$(hardened_make_run_tmp "$SCRIPT_DIR")"
OUTPUT_DIR="$RUN_TMP/license-output"
hardened_ensure_private_dir "$OUTPUT_DIR"
cleanup() { rm -rf -- "$RUN_TMP"; }
trap cleanup EXIT INT TERM

hardened_resolve_host_identity
uid="$HARDENED_HOST_UID"
gid="$HARDENED_HOST_GID"

docker_args=(
    run --rm -it
    --platform "$PLATFORM"
    --user 0:0
    --init
    --cap-drop=ALL
    --cap-add=CHOWN
    --cap-add=DAC_OVERRIDE
    --security-opt=no-new-privileges:true
    --pids-limit 128
    --memory 2g
    --cpus 1
)
if (( ALLOW_NETWORK )); then
    hardened_warn "Stata activation container has outbound network access for this run"
else
    docker_args+=(--network none)
fi
docker_args+=(
    --tmpfs /tmp:rw,exec,nosuid,nodev,size=256m
    --tmpfs /root:rw,nosuid,nodev,size=64m
    --mount "type=bind,src=$OUTPUT_DIR,dst=/license-output"
    --entrypoint /opt/agent/stata-license-helper
    "$IMAGE_NAME" "$uid" "$gid"
)
docker "${docker_args[@]}"

[[ -s "$OUTPUT_DIR/stata.lic" ]] || hardened_die "Stata license was not created"
install -m 0600 "$OUTPUT_DIR/stata.lic" "$SCRIPT_DIR/auth/STATA.LIC"
printf 'Stored the Stata license at %s with mode 0600.\n' "$SCRIPT_DIR/auth/STATA.LIC"
    