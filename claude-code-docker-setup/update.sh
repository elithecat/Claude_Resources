#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
usage(){ printf 'Usage: ./update.sh [codex-version] [claude-version]\nOmitted versions keep the pins in config.env.\n'; }
[[ "${1:-}" == -h || "${1:-}" == --help ]] && { usage; exit 0; }
CODEX_NEW="${1:-}"; CLAUDE_NEW="${2:-}"
for pair in "CODEX_VERSION:$CODEX_NEW" "CLAUDE_VERSION:$CLAUDE_NEW"; do
    key="${pair%%:*}"; val="${pair#*:}"
    [[ -z "$val" ]] && continue
    [[ "$val" =~ ^[0-9][0-9A-Za-z.-]*$ ]] || { printf 'bad version: %s\n' "$val" >&2; exit 1; }
    python3 -I - "$SCRIPT_DIR/config.env" "$key" "$val" <<'PY'
import sys, pathlib
p, key, val = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
lines = p.read_text().splitlines()
out = [f"{key}={val}" if l.startswith(key + "=") else l for l in lines]
p.write_text("\n".join(out) + "\n")
print(f"{key} -> {val}")
PY
done
exec "$SCRIPT_DIR/setup.sh"
