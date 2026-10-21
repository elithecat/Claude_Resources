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


SECRETS_DIR="$SCRIPT_DIR/auth/secrets"
CHATGPT_DIR="$SCRIPT_DIR/auth/codex"
CHATGPT_AUTH="$CHATGPT_DIR/auth.json"
hardened_ensure_private_dir "$SCRIPT_DIR/auth"
hardened_ensure_private_dir "$SECRETS_DIR"
hardened_ensure_private_dir "$CHATGPT_DIR"

store_api_key() {
    local from_stdin="$1" value temp
    if [[ "$from_stdin" == 1 ]]; then
        IFS= read -r value
    else
        [[ -t 0 ]] || hardened_die "API key requires a terminal or --stdin"
        IFS= read -r -s -p 'OpenAI API key: ' value
        printf '\n'
    fi
    [[ -n "$value" && ${#value} -le 8192 ]] || hardened_die "credential is empty or too long"
    [[ "$value" != *[[:space:]]* && "$value" != *$'\r'* && "$value" != *$'\n'* ]] || hardened_die "credential contains whitespace"
    temp="$(mktemp "$SECRETS_DIR/.credential.XXXXXXXX")"
    chmod 600 "$temp"
    printf '%s' "$value" > "$temp"
    mv -f -- "$temp" "$SECRETS_DIR/codex_api_key"
    chmod 600 "$SECRETS_DIR/codex_api_key"
    unset value
    printf 'Stored API credential in %s; its contents were not displayed.\n' "$SECRETS_DIR/codex_api_key"
}

chatgpt_login() {
    local uid gid
    hardened_require_command docker
    hardened_resolve_host_identity
    uid="$HARDENED_HOST_UID"
    gid="$HARDENED_HOST_GID"

    cat <<'EOF_LOGIN'
Starting Codex device-code login for ChatGPT subscription access.
Open the displayed link in your browser, sign in to the ChatGPT account that
has your subscription, and enter the one-time code.
EOF_LOGIN

    docker run --rm -it \
        --platform "$PLATFORM" \
        --user "$uid:$gid" \
        --init \
        --read-only \
        --cap-drop=ALL \
        --security-opt=no-new-privileges:true \
        --pids-limit 128 \
        --memory 1g \
        --cpus 1 \
        --tmpfs "/tmp:rw,exec,nosuid,nodev,size=256m,uid=$uid,gid=$gid" \
        --tmpfs "/var/tmp:rw,exec,nosuid,nodev,size=128m,uid=$uid,gid=$gid" \
        --tmpfs "/run:rw,nosuid,nodev,size=32m,uid=$uid,gid=$gid" \
        --tmpfs "/home/agent:rw,exec,nosuid,nodev,size=256m,uid=$uid,gid=$gid,mode=0700" \
        --mount "type=bind,src=$CHATGPT_DIR,dst=/home/agent/.codex" \
        -e HOME=/home/agent \
        -e CODEX_HOME=/home/agent/.codex \
        -e AGENT_KIND=codex \
        "$IMAGE_NAME" \
        codex \
        -c 'model_provider="openai"' \
        -c 'cli_auth_credentials_store="file"' \
        -c 'forced_login_method="chatgpt"' \
        login --device-auth

    hardened_secret_file "$CHATGPT_AUTH" "Codex ChatGPT authentication cache" >/dev/null
    printf 'ChatGPT subscription authentication stored at %s.\n' "$CHATGPT_AUTH"
}

show_status() {
    local found=0
    if [[ -e "$CHATGPT_AUTH" || -L "$CHATGPT_AUTH" ]]; then
        hardened_secret_file "$CHATGPT_AUTH" "Codex ChatGPT authentication cache" >/dev/null
        printf 'ChatGPT subscription: configured\n'
        found=1
    else
        printf 'ChatGPT subscription: absent\n'
    fi
    if [[ -e "$SECRETS_DIR/codex_api_key" || -L "$SECRETS_DIR/codex_api_key" ]]; then
        hardened_secret_file "$SECRETS_DIR/codex_api_key" "OpenAI API key" >/dev/null
        printf 'OpenAI API key: configured\n'
        found=1
    else
        printf 'OpenAI API key: absent\n'
    fi
    return $(( found == 1 ? 0 : 1 ))
}

command="${1:-status}"
case "$command" in
    chatgpt|login|device-auth)
        (($# == 1)) || hardened_die "usage: ./authenticate-codex.sh chatgpt"
        chatgpt_login
        ;;
    api-key)
        from_stdin=0
        [[ "${2:-}" == --stdin ]] && from_stdin=1
        (($# <= 2)) || hardened_die "usage: ./authenticate-codex.sh api-key [--stdin]"
        store_api_key "$from_stdin"
        ;;
    status)
        (($# <= 1)) || hardened_die "usage: ./authenticate-codex.sh status"
        show_status
        ;;
    logout)
        (($# == 1)) || hardened_die "usage: ./authenticate-codex.sh logout"
        rm -f -- "$CHATGPT_AUTH" "$SECRETS_DIR/codex_api_key"
        printf 'Removed stored Codex ChatGPT and API-key credentials.\n'
        ;;
    *)
        cat >&2 <<'EOF'
Usage:
  ./authenticate-codex.sh chatgpt
  ./authenticate-codex.sh api-key [--stdin]
  ./authenticate-codex.sh status
  ./authenticate-codex.sh logout

The default is ChatGPT device-code login, which uses your eligible ChatGPT
subscription. API-key mode remains available and uses separate API billing.
EOF
        exit 2
        ;;
esac
