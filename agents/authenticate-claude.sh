#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
hardened_load_config "$SCRIPT_DIR/config.env"
IMAGE_NAME="${IMAGE_NAME:-agents-research}"
PROXY_IMAGE_NAME="${PROXY_IMAGE_NAME:-agents-research-proxy}"
AGENT_VERSION="${AGENT_VERSION:-2.1.209}"
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
    
    
SECRETS_DIR="$SCRIPT_DIR/auth/secrets"
hardened_ensure_private_dir "$SCRIPT_DIR/auth"
hardened_ensure_private_dir "$SECRETS_DIR"

store_secret() {
    local destination="$1" label="$2" from_stdin="$3" value temp
    if [[ "$from_stdin" == 1 ]]; then
        IFS= read -r value
    else
        [[ -t 0 ]] || hardened_die "$label requires a terminal or --stdin"
        IFS= read -r -s -p "$label: " value
        printf '\n'
    fi
    [[ -n "$value" && ${#value} -le 8192 ]] || hardened_die "credential is empty or too long"
    [[ "$value" != *[[:space:]]* && "$value" != *$'\r'* && "$value" != *$'\n'* ]] || hardened_die "credential contains whitespace"
    temp="$(mktemp "$SECRETS_DIR/.credential.XXXXXXXX")"
    chmod 600 "$temp"
    printf '%s' "$value" > "$temp"
    mv -f -- "$temp" "$destination"
    chmod 600 "$destination"
    unset value
    printf 'Stored credential in %s; its contents were not displayed.\n' "$destination"
}

command="${1:-status}"
case "$command" in
    api-key)
        from_stdin=0
        [[ "${2:-}" == --stdin ]] && from_stdin=1
        (($# <= 2)) || hardened_die "usage: ./authenticate-claude.sh api-key [--stdin]"
        store_secret "$SECRETS_DIR/claude_api_key" "Anthropic API key" "$from_stdin"
        ;;
    setup-token)
        (($# == 1)) || hardened_die "usage: ./authenticate-claude.sh setup-token"
        hardened_require_command docker
        cat <<'EOF'
The official `claude setup-token` flow will run in an otherwise empty
credential-only container. Copy the token it prints, exit that command,
then paste it at the hidden prompt. No .credentials.json is fabricated.
EOF
        hardened_resolve_host_identity
        host_uid="$HARDENED_HOST_UID"
        host_gid="$HARDENED_HOST_GID"
        docker run --rm -it \
            --platform "$PLATFORM" \
            --init \
            --read-only \
            --user "$host_uid:$host_gid" \
            --cap-drop=ALL \
            --security-opt=no-new-privileges:true \
            --pids-limit 128 \
            --memory 1g \
            --cpus 1 \
            --tmpfs "/tmp:rw,exec,nosuid,nodev,size=256m,uid=$host_uid,gid=$host_gid" \
            --tmpfs "/home/agent:rw,exec,nosuid,nodev,size=512m,uid=$host_uid,gid=$host_gid,mode=0700" \
            -e AGENT_KIND=claude \
            "$IMAGE_NAME" claude setup-token
        store_secret "$SECRETS_DIR/claude_setup_token" "Claude setup token" 0
        ;;
    setup-token-stdin)
        (($# == 1)) || hardened_die "usage: ./authenticate-claude.sh setup-token-stdin"
        store_secret "$SECRETS_DIR/claude_setup_token" "Claude setup token" 1
        ;;
    status)
        (($# <= 1)) || hardened_die "usage: ./authenticate-claude.sh status"
        [[ -s "$SECRETS_DIR/claude_api_key" ]] && printf 'Anthropic API key: configured\n' || printf 'Anthropic API key: absent\n'
        [[ -s "$SECRETS_DIR/claude_setup_token" ]] && printf 'Claude setup token: configured\n' || printf 'Claude setup token: absent\n'
        ;;
    logout)
        (($# == 1)) || hardened_die "usage: ./authenticate-claude.sh logout"
        rm -f -- "$SECRETS_DIR/claude_api_key" "$SECRETS_DIR/claude_setup_token"
        printf 'Removed stored Claude credentials.\n'
        ;;
    *)
        cat >&2 <<'EOF'
Usage:
  ./authenticate-claude.sh api-key [--stdin]
  ./authenticate-claude.sh setup-token
  ./authenticate-claude.sh setup-token-stdin
  ./authenticate-claude.sh status
  ./authenticate-claude.sh logout
EOF
        exit 2
        ;;
esac
        