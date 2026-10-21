#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
for f in go ps clean review shell.sh setup.sh update.sh clone-private.sh enter-running.sh \
         authenticate-codex.sh authenticate-claude.sh authenticate-github.sh \
         container-entrypoint.sh github-helper.sh stata-license-helper.sh lib/common.sh; do
    bash -n "$f"
done
node --check credential-proxy.mjs
node --check codex-egress-proxy.mjs
python3 -I - <<'PY'
import json, tomllib
tomllib.load(open("codex-system-config.toml","rb"))
json.load(open("managed-default.json")); json.load(open("managed-locked.json"))
PY
# Codex must NOT be in permission-profile mode: that makes it nest a bubblewrap
# sandbox which cannot start in this cap-dropped container.
! grep -q '^default_permissions' codex-system-config.toml
! grep -q '^\[permissions\.' codex-system-config.toml
grep -q -- '--dangerously-bypass-approvals-and-sandbox' go
! grep -q -- 'docker_args+=(--ask-for-approval' go
! grep -q '/home/codex' codex-system-config.toml
grep -q 'skipDangerousModePermissionPrompt' managed-locked.json
grep -q 'skipDangerousModePermissionPrompt' managed-default.json
# CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1 silently overrides --dangerously-skip-permissions
# and re-invokes bubblewrap (--unshare-pid --proc /proc), which cannot work in this
# cap-dropped container. It must never be 1.
! grep -q 'CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1' go
grep -q 'CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=0' go
# A repo must never be able to supply Claude settings (pre-approved permissions)
# and the trust dialog must not reappear every run.
grep -q -- '--setting-sources user' go
! grep -q 'disableAllHooks' managed-default.json
grep -q 'AGENTS-locked.md' Dockerfile
grep -qE 'claude-code@\$\{CLAUDE_VERSION\}' Dockerfile
! grep -E 'git -C "\$PROJECT_PATH"' go >/dev/null
grep -q 'GIT_CONFIG_NOSYSTEM' review
grep -q 'exclude=.git' review
bash "$ROOT/tests/security-git-config.sh" >/dev/null
! grep -q 'env -u CLAUDE_CODE_SUBPROCESS_ENV_SCRUB' go
grep -q 'project_doc_max_bytes=32768' go
! grep -q 'rm -rf -- "$SCRATCH' go
grep -q './clean' go
! grep -qw 'DIRECT' go
grep -q 'gateway_mode_ipv4=isolated' lib/common.sh
grep -q 'agents.proxy=1' lib/common.sh
grep -q 'openai-api-key' go
grep -q 'pwd -P' clean
grep -q 'core.hooksPath=/dev/null' go
grep -q 'not overridable' review
grep -q 'MAX_WORKSPACE_KB' go
grep -q 'decodeURIComponent' credential-proxy.mjs
grep -q 'routes through .git' review
! grep -q 'realpath -m' review
grep -q 'resolve()' review
grep -q 'digits only' go
! grep -q -- 'docker_args+=(--safe-mode' go
grep -q -- '-print0' review
grep -q "read -r -d ''" review
! grep -q 'may reach host-bound services' lib/common.sh
grep -q 'hardened_cleanup_proxy' go
grep -q 'add -Af' review
grep -q -- 'rsync -rl --checksum' review
grep -q 'nested git' review
! grep -q 'DIRS=("$SC"/\*/)' clean
grep -q 'is a symlink' clean
grep -q '.claude/projects' go
grep -q 'showSignature = false' lib/common.sh
python3 -I - <<'PY'
import pathlib
m = pathlib.Path('credential-proxy.mjs').read_text()
assert m.index('acceptedRequests += 1') < m.index('await readBody'), 'proxy must reserve before reading'
PY
printf 'Static smoke checks passed.\n'
