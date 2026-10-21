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

PORT_OFFSET=0
PORTS_ENABLED=0
TRUSTED=0
WITH_STATA=0
ALLOW_NETWORK=0
PERSIST_CACHE=0
GITHUB_CREDS=0
DRY_RUN=0

usage() {
    cat <<'EOF_USAGE'
Usage:
  ./shell.sh [options] [project-path]

Options:
  -p, --port-offset N  Publish 3000/5173/8080/8888 plus N on 127.0.0.1;
                        requires --trusted --allow-network in shell mode
  --with-stata         Mount auth/STATA.LIC read-only; requires --trusted
  --allow-network      Give this manual shell general internet; requires --trusted
  --persist-cache      Reuse this project's package cache; requires --trusted
  --github-creds       Mount the reusable GitHub credential read-only so
                        git clone/pull of private repositories works;
                        requires --trusted --allow-network
  --trusted            Acknowledge the requested credential/network exposure
  --dry-run            Print the Docker command without starting it
  -h, --help           Show this help

This starts a fresh Bash shell in the research image. It does not start the
coding agent and does not mount model, GitHub, or SSH credentials. With no
project path, it uses this package's project/ folder.
EOF_USAGE
}

while (($#)); do
    case "$1" in
        -p|--port-offset)
            (($# >= 2)) || hardened_die "$1 requires a value"
            hardened_validate_port_offset "$2"
            PORTS_ENABLED=1
            shift 2
            ;;
        --with-stata) WITH_STATA=1; shift ;;
        --allow-network) ALLOW_NETWORK=1; shift ;;
        --persist-cache) PERSIST_CACHE=1; shift ;;
        --github-creds) GITHUB_CREDS=1; shift ;;
        --trusted) TRUSTED=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        -*) hardened_die "unknown option: $1" ;;
        *) break ;;
    esac
done

(($# <= 1)) || { usage >&2; exit 2; }
if (( PORTS_ENABLED && ! ALLOW_NETWORK )); then
    hardened_die "-p requires --trusted --allow-network in shell.sh; the offline --network none shell cannot publish ports"
fi
if (( WITH_STATA || ALLOW_NETWORK || PERSIST_CACHE || GITHUB_CREDS )); then
    (( TRUSTED == 1 )) || hardened_die "--with-stata, --allow-network, --persist-cache, and --github-creds require --trusted"
fi
if (( GITHUB_CREDS )); then
    (( ALLOW_NETWORK )) || hardened_die "--github-creds requires --allow-network; without network the credential has nothing to reach"
    hardened_reject_symlink_components "$SCRIPT_DIR/auth/gh" "GitHub credential directory"
    [[ -d "$SCRIPT_DIR/auth/gh" && ! -L "$SCRIPT_DIR/auth/gh" ]] || hardened_die "GitHub credential directory is unsafe"
    hardened_dir_has_files "$SCRIPT_DIR/auth/gh" || hardened_die "GitHub authentication is missing; run ./authenticate-github.sh login"
fi

if (($# == 1)); then
    PROJECT_PATH="$(hardened_canonical_dir "$1")"
else
    hardened_ensure_private_dir "$SCRIPT_DIR/project"
    PROJECT_PATH="$(hardened_canonical_dir "$SCRIPT_DIR/project")"
fi
hardened_validate_project_path "$SCRIPT_DIR" "$PROJECT_PATH"

PROJECT_STATE="$(hardened_project_state_dir "$SCRIPT_DIR" "$PROJECT_PATH")"
RUN_TMP="$(hardened_make_run_tmp "$SCRIPT_DIR")"
GITCONFIG="$RUN_TMP/gitconfig"
hardened_make_gitconfig "$GITCONFIG"

cleanup() {
    local status=$?
    trap - EXIT INT TERM
    rm -rf -- "$RUN_TMP"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if (( DRY_RUN == 0 )); then hardened_require_command docker; fi
hardened_build_security_args
hardened_add_git_environment
PORT_SUMMARY=none

docker_args=(
    run --rm -it
    --platform "$PLATFORM"
    "${SECURITY_ARGS[@]}"
)
if (( ALLOW_NETWORK )); then
    docker_args+=(--network bridge)
else
    docker_args+=(--network none)
fi
if (( PORTS_ENABLED )); then
    PORT_A=$((3000 + PORT_OFFSET))
    PORT_B=$((5173 + PORT_OFFSET))
    PORT_C=$((8080 + PORT_OFFSET))
    PORT_D=$((8888 + PORT_OFFSET))
    docker_args+=(
        --publish "127.0.0.1:${PORT_A}:3000"
        --publish "127.0.0.1:${PORT_B}:5173"
        --publish "127.0.0.1:${PORT_C}:8080"
        --publish "127.0.0.1:${PORT_D}:8888"
    )
    PORT_SUMMARY="127.0.0.1:$PORT_A, $PORT_B, $PORT_C, $PORT_D"
fi
docker_args+=(
    --mount "type=bind,src=$PROJECT_PATH,dst=/workspace"
    --mount "type=bind,src=$GITCONFIG,dst=/etc/agent-gitconfig,readonly"
)
docker_args+=("${GIT_ENV_ARGS[@]}")
if (( GITHUB_CREDS )); then
    docker_args+=(
        --mount "type=bind,src=$SCRIPT_DIR/auth/gh,dst=/gh,readonly"
        -e GH_CONFIG_DIR=/gh
        -e "GIT_CONFIG_VALUE_1=!gh auth git-credential"
    )
fi
if (( PERSIST_CACHE )); then
    docker_args+=(
        --mount "type=bind,src=$PROJECT_STATE/R,dst=/home/agent/R/library"
        --mount "type=bind,src=$PROJECT_STATE/python,dst=/home/agent/.local"
        --mount "type=bind,src=$PROJECT_STATE/stata-ado,dst=/home/agent/ado"
    )
fi
if (( WITH_STATA )); then
    STATA_LICENSE="$(hardened_secret_file "$SCRIPT_DIR/auth/STATA.LIC" "Stata license")"
    docker_args+=(--mount "type=bind,src=$STATA_LICENSE,dst=/usr/local/stata/stata.lic,readonly")
fi
docker_args+=(-e AGENT_KIND=codex "$IMAGE_NAME" bash --noprofile --norc)

cat <<EOF_STATUS
=== Hardened research shell ===
Project:        $PROJECT_PATH
Model agent:    not started
Network:        $([[ "$ALLOW_NETWORK" == 1 ]] && printf 'general egress enabled' || printf 'none')
Ports:          $PORT_SUMMARY
Stata license:  $([[ "$WITH_STATA" == 1 ]] && printf 'mounted read-only' || printf 'not mounted')
Credentials:    no model or SSH credential is mounted; GitHub token $([[ "$GITHUB_CREDS" == 1 ]] && printf 'mounted read-only' || printf 'not mounted')
Package cache:  $([[ "$PERSIST_CACHE" == 1 ]] && printf 'project-scoped and persistent' || printf 'ephemeral')
Exit:           type exit or press Ctrl-D
EOF_STATUS
if (( WITH_STATA )); then hardened_warn "trusted mode exposes the Stata license to this manual shell"; fi
if (( ALLOW_NETWORK )); then hardened_warn "trusted mode permits shell commands to reach the internet"; fi
if (( GITHUB_CREDS )); then hardened_warn "trusted mode exposes your reusable GitHub token to everything in this shell"; fi
if (( PERSIST_CACHE )); then hardened_warn "trusted mode permits code to persist in this project's package cache"; fi

if (( DRY_RUN )); then
    hardened_print_command docker "${docker_args[@]}"
else
    docker "${docker_args[@]}"
fi
