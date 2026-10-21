#!/usr/bin/env bash
set -euo pipefail
umask 077

# Launchers run as the invoking non-root host UID/GID so bind-mounted output has
# the correct owner. That numeric identity often has no entry in the image's
# /etc/passwd (macOS commonly uses UID 501). nss_wrapper supplies a process-local
# identity without making /etc writable or starting the container as root.
uid="$(id -u)"
gid="$(id -g)"
[[ "$uid" != 0 ]] || { printf 'Refusing to run the agent as container root.\n' >&2; exit 77; }
agent_name="${AGENT_KIND:-agent}"
nss_dir="$HOME/.nss-wrapper"
mkdir -p "$nss_dir"
awk -F: -v uid="$uid" -v name="$agent_name" '$1 != name && $3 != uid { print }' /etc/passwd > "$nss_dir/passwd"
printf '%s:x:%s:%s:Hardened agent:%s:/bin/bash\n' "$agent_name" "$uid" "$gid" "$HOME" >> "$nss_dir/passwd"
awk -F: -v gid="$gid" -v name="$agent_name" '$1 != name && $3 != gid { print }' /etc/group > "$nss_dir/group"
printf '%s:x:%s:\n' "$agent_name" "$gid" >> "$nss_dir/group"
chmod 600 "$nss_dir/passwd" "$nss_dir/group"
export NSS_WRAPPER_PASSWD="$nss_dir/passwd"
export NSS_WRAPPER_GROUP="$nss_dir/group"
export LD_PRELOAD=/usr/local/lib/libnss_wrapper.so

mkdir -p "$HOME/.config/nbstata" "$HOME/R/library" "$HOME/.local" "$HOME/ado/plus" "$HOME/outputs"
if [[ -f /opt/agent/nbstata.conf ]]; then
    install -m 0600 /opt/agent/nbstata.conf "$HOME/.config/nbstata/nbstata.conf"
fi

case "${AGENT_KIND:-}" in
    claude)
        mkdir -p "$HOME/.claude"
        # Seed .claude.json so Claude does not prompt at startup. Marking
        # /workspace as an already-trusted project suppresses the "Is this a
        # project you trust?" dialog, which otherwise fires every run because the
        # container home is a fresh tmpfs and the folder is always /workspace.
        # Trust is not a security boundary here; the container is.
        if [[ ! -e "$HOME/.claude.json" ]]; then
            if command -v python3 >/dev/null 2>&1; then
                python3 - <<'PYSEED' > "$HOME/.claude.json"
import json
print(json.dumps({
    "hasCompletedOnboarding": True,
    "theme": "dark",
    "hasTrustDialogAccepted": True,
    "projects": {
        "/workspace": {
            "hasTrustDialogAccepted": True,
            "hasCompletedProjectOnboarding": True,
            "allowedTools": []
        }
    }
}))
PYSEED
            else
                printf '%s\n' '{"hasCompletedOnboarding":true,"theme":"dark","hasTrustDialogAccepted":true,"projects":{"/workspace":{"hasTrustDialogAccepted":true,"hasCompletedProjectOnboarding":true,"allowedTools":[]}}}' > "$HOME/.claude.json"
            fi
            chmod 600 "$HOME/.claude.json"
        fi
        ;;
    codex)
        export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
        mkdir -p "$CODEX_HOME"
        install -m 0400 /etc/codex/config.toml "$CODEX_HOME/config.toml"
        ;;
    *)
        printf 'Unknown AGENT_KIND: %s\n' "${AGENT_KIND:-unset}" >&2
        exit 70
        ;;
esac

exec "$@"
