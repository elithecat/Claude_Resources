#!/usr/bin/env bash
# Restart the model-credential proxy sidecar with a fresh (optionally larger)
# request budget, WITHOUT stopping the agent session that is using it.
#
# Why this works: the budget counter lives in the sidecar process, and the agent
# reaches the sidecar through a stable container name and the "model-api"
# network alias. Recreating the sidecar with the same name, networks and mounts
# resets the counter; the agent's own retry loop reconnects on its next attempt.
#
# Usage:
#   ./bump-proxy-limit.sh            # reset the counter, keep the current limit
#   ./bump-proxy-limit.sh 50000      # reset and raise the limit
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

NEW_LIMIT="${1:-}"
if [[ -n "$NEW_LIMIT" && ! "$NEW_LIMIT" =~ ^[1-9][0-9]*$ ]]; then
    printf 'limit must be a positive integer\n' >&2; exit 2
fi

command -v docker >/dev/null || { printf 'docker not found\n' >&2; exit 1; }

mapfile -t PROXIES < <(docker ps -q --filter 'label=agents.proxy=1')
if (( ${#PROXIES[@]} == 0 )); then
    printf 'No running proxy sidecar found. Is a session active?\n' >&2; exit 1
fi
if (( ${#PROXIES[@]} > 1 )); then
    printf 'More than one proxy is running; refusing to guess which one.\n' >&2
    docker ps --filter 'label=agents.proxy=1' --format '  {{.Names}}' >&2
    exit 1
fi
CID="${PROXIES[0]}"

NAME="$(docker inspect -f '{{.Name}}' "$CID" | sed 's|^/||')"
IMAGE="$(docker inspect -f '{{.Config.Image}}' "$CID")"
USERSPEC="$(docker inspect -f '{{.Config.User}}' "$CID")"
PLATFORM_ARG=()
# Recover the env we must preserve.
MODE="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$CID" | sed -n 's/^PROXY_MODE=//p' | head -1)"
CUR_LIMIT="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$CID" | sed -n 's/^PROXY_MAX_REQUESTS=//p' | head -1)"
LIMIT="${NEW_LIMIT:-$CUR_LIMIT}"
[[ -n "$MODE" ]] || { printf 'could not read PROXY_MODE from the running proxy\n' >&2; exit 1; }

# Mounts (source:destination pairs, read-only).
mapfile -t MOUNT_ARGS < <(
  docker inspect -f '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}::{{.Destination}}{{println}}{{end}}{{end}}' "$CID" \
  | while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        src="${line%%::*}"; dst="${line##*::}"
        printf -- '--mount\ntype=bind,src=%s,dst=%s,readonly\n' "$src" "$dst"
    done
)

# Networks it is attached to, in order.
mapfile -t NETS < <(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{println $k}}{{end}}' "$CID" | sed '/^$/d')
(( ${#NETS[@]} >= 1 )) || { printf 'proxy has no networks; refusing\n' >&2; exit 1; }

printf 'Proxy:        %s\n' "$NAME"
printf 'Mode:         %s\n' "$MODE"
printf 'Limit:        %s -> %s\n' "${CUR_LIMIT:-?}" "$LIMIT"
printf 'Networks:     %s\n' "${NETS[*]}"
printf '\nThis recreates the sidecar. The agent session keeps running and reconnects\n'
printf 'on its next retry. Type '"'"'yes'"'"' to proceed: '
if [[ -t 0 ]]; then read -r -t 0.1 -n 10000 _discard 2>/dev/null || true; fi
read -r ok
[[ "$ok" == yes ]] || { printf 'aborted\n'; exit 1; }

docker rm -f "$CID" >/dev/null

# Recreate on the first network with the model-api alias, then attach the rest.
docker run -d \
    --label agents.proxy=1 \
    --label hardened.component=model-credential-proxy \
    --name "$NAME" \
    --network "${NETS[0]}" \
    --network-alias model-api \
    ${USERSPEC:+--user "$USERSPEC"} \
    --init \
    --read-only \
    --cap-drop=ALL \
    --security-opt=no-new-privileges:true \
    --pids-limit 64 \
    --memory 256m \
    --cpus 0.5 \
    --tmpfs "/tmp:rw,nosuid,nodev,size=32m" \
    --tmpfs "/run:rw,nosuid,nodev,size=16m" \
    "${MOUNT_ARGS[@]}" \
    -e "PROXY_MODE=$MODE" \
    -e "PROXY_MAX_REQUESTS=$LIMIT" \
    "$IMAGE" >/dev/null

for ((i = 1; i < ${#NETS[@]}; i++)); do
    docker network connect --alias model-api "${NETS[$i]}" "$NAME" >/dev/null
done

printf 'Proxy restarted with budget %s. The session should resume on its next retry.\n' "$LIMIT"
printf 'To make this permanent, set PROXY_MAX_REQUESTS_INTERACTIVE in config.env.\n'
