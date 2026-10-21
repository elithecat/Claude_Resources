#!/usr/bin/env bash
# END-TO-END GATE: proves each agent can actually execute a shell command inside
# the container. This is the test whose absence let sandbox-incompatibility ship.
# Requires Docker and a built image; run it on the target machine, not in CI
# sandboxes that lack Docker. It uses --once so no interaction is needed.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

command -v docker >/dev/null || { echo "SKIP: docker not available"; exit 0; }
# Locked Codex uses the API-key proxy; skip it cleanly if that key is absent.
have_codex_key=1
[[ -s "$ROOT/auth/secrets/codex_api_key" ]] || have_codex_key=0
docker image inspect "${IMAGE_NAME:-agents-research}" >/dev/null 2>&1 || {
    echo "SKIP: image not built; run ./setup.sh first"; exit 0; }

work="$(mktemp -d)"; ( cd "$work" && git init -q && echo "hello" > file.txt \
    && git -c user.name=t -c user.email=t@e add -A \
    && git -c user.name=t -c user.email=t@e commit -qm init )

fail=0
for agent in codex claude; do
    if [[ "$agent" == codex && "$have_codex_key" == 0 ]]; then
        echo "=== codex: SKIP (locked codex needs ./authenticate-codex.sh api-key) ==="
        continue
    fi
    echo "=== $agent: execute a shell command end to end ==="
    # --locked needs no Stata license or GitHub token, so this gate can run
    # before those are configured; it still exercises real shell execution.
    out="$(./go --once --locked "$agent" "$work" \
        "Run exactly this command and nothing else: ls -la /workspace. Then stop." 2>&1 || true)"
    if grep -qi "bwrap\|No permissions to create new namespace\|Can't mount proc" <<<"$out"; then
        echo "  FAIL: $agent hit a sandbox error executing a command"
        echo "$out" | tail -5
        fail=1
    elif grep -q "file.txt" <<<"$out"; then
        echo "  PASS: $agent listed the workspace (shell execution works)"
    else
        echo "  INCONCLUSIVE: no bwrap error, but did not see expected output"
        echo "$out" | tail -8
        fail=1
    fi
done
rm -rf "$work"
(( fail == 0 )) && echo "=== agent shell execution gate: PASS ===" || { echo "=== agent shell execution gate: FAIL ==="; exit 1; }
