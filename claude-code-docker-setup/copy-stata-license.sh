#!/usr/bin/env bash
set -euo pipefail
umask 077
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SRC="${1:-/Applications/Stata/stata.lic}"
[[ -f "$SRC" && ! -L "$SRC" ]] || { printf 'no license file at %s\n' "$SRC" >&2; exit 1; }
AUTH="$SCRIPT_DIR/auth"
mkdir -p -m 700 "$AUTH"
[[ -d "$AUTH" && ! -L "$AUTH" ]] || { printf 'auth directory is unsafe\n' >&2; exit 1; }
DEST="$AUTH/STATA.LIC"
[[ ! -L "$DEST" ]] || { printf 'refusing to write through a symlink at %s\n' "$DEST" >&2; exit 1; }
TMP="$(mktemp "$AUTH/.stata.XXXXXXXX")"
cp -- "$SRC" "$TMP"
chmod 600 "$TMP"
mv -f -- "$TMP" "$DEST"
printf 'Stata license stored at %s\n' "$DEST"
