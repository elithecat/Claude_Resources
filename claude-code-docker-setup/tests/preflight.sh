#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
WORK="$(mktemp -d)"
cp -a "$ROOT/." "$WORK/pkg"
rm -f "$WORK/pkg/config.env"
mkdir -p "$WORK/bin"
printf '#!/usr/bin/env bash\ncase "$1" in build) echo "stub build ok";; *) exit 0;; esac\n' > "$WORK/bin/docker"
chmod 755 "$WORK/bin/docker"
cd "$WORK/pkg"
if PATH="$WORK/bin:$PATH" bash setup.sh >"$WORK/out" 2>&1; then
    grep -q "stub build ok" "$WORK/out" && printf 'preflight: fresh setup reaches the build step\n'
else
    printf 'preflight FAILED:\n' >&2; tail -5 "$WORK/out" >&2; exit 1
fi
[[ -f config.env ]] && printf 'preflight: config.env created before load\n'
