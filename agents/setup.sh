#!/usr/bin/env bash
set -euo pipefail
umask 077
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/lib/common.sh"
[[ -f "$SCRIPT_DIR/config.env" ]] || cp "$SCRIPT_DIR/config.env.example" "$SCRIPT_DIR/config.env"
hardened_load_config "$SCRIPT_DIR/config.env"
IMAGE_NAME="${IMAGE_NAME:-agents-research}"
PROXY_IMAGE_NAME="${PROXY_IMAGE_NAME:-agents-research-proxy}"
CODEX_VERSION="${CODEX_VERSION:-0.144.4}"
CLAUDE_VERSION="${CLAUDE_VERSION:-2.1.209}"
PLATFORM="${PLATFORM:-linux/amd64}"
STATA_IMAGE="${STATA_IMAGE:-dataeditors/stata19-se-i-python@sha256:1691fce6250011bef77cb64df58316bc72ed82b9791456e4b804832d9bfd747d}"
STATA_EDITION="${STATA_EDITION:-se}"
AGENT_VERSION="${AGENT_VERSION:-$CODEX_VERSION}"
GIT_USER_NAME="${GIT_USER_NAME:-Research Agent}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-research-agent@users.noreply.github.com}"
MEMORY_LIMIT="${MEMORY_LIMIT:-16g}"
CPU_LIMIT="${CPU_LIMIT:-4}"
PIDS_LIMIT="${PIDS_LIMIT:-512}"
SHM_SIZE="${SHM_SIZE:-1g}"
PROXY_MAX_REQUESTS_INTERACTIVE="${PROXY_MAX_REQUESTS_INTERACTIVE:-1000}"
PROXY_MAX_REQUESTS_AUTONOMOUS="${PROXY_MAX_REQUESTS_AUTONOMOUS:-2000}"
export AGENT_USER=agent
hardened_validate_common_config
export AGENT_USER=agent
hardened_validate_common_config
hardened_require_command docker
chmod +x "$SCRIPT_DIR"/go "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/ps "$SCRIPT_DIR"/clean "$SCRIPT_DIR"/review "$SCRIPT_DIR"/enter-running.sh 2>/dev/null || true
for d in auth auth/secrets auth/gh auth/codex state pending worktrees scratch; do
    hardened_ensure_private_dir "$SCRIPT_DIR/$d"
done
bash "$SCRIPT_DIR/tests/smoke.sh"
printf '=== Building the proxy image ===\n'
DOCKER_BUILDKIT=1 docker build --pull --platform "$PLATFORM" --target credential-proxy -t "$PROXY_IMAGE_NAME" "$SCRIPT_DIR"
printf '=== Building the unified agent image (heavy layers cache-share with v16) ===\n'
DOCKER_BUILDKIT=1 docker build --pull --platform "$PLATFORM" --target agent \
    --build-arg "CODEX_VERSION=$CODEX_VERSION" \
    --build-arg "CLAUDE_VERSION=$CLAUDE_VERSION" \
    --build-arg "STATA_IMAGE=$STATA_IMAGE" \
    --build-arg "STATA_EDITION=$STATA_EDITION" \
    -t "$IMAGE_NAME" "$SCRIPT_DIR"
printf '\nSetup complete. Next:\n  ./authenticate-codex.sh chatgpt\n  ./authenticate-claude.sh setup-token\n  ./authenticate-github.sh login\n  ./copy-stata-license.sh   (defaults to /Applications/Stata/stata.lic)\nThen:  ./go codex ~/Documents/repos/YourProject "hello"\n'
