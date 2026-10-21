#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT/lib/common.sh"
tmp="$(mktemp -d)"
mkrsync() { cat > "$1/rsync" <<'RS'
#!/usr/bin/env bash
del=0;exg=0;args=()
for a in "$@";do case "$a" in --delete)del=1;;--exclude=.git)exg=1;;-a|-rlt|-rl|--checksum|--ignore-times|--);;*)args+=("$a");;esac;done
mkdir -p "${args[1]}";(( del ))&&find "${args[1]}" -mindepth 1 -delete;cp -a "${args[0]}". "${args[1]}" 2>/dev/null||true;(( exg ))&&rm -rf "${args[1]}/.git";true
RS
chmod +x "$1/rsync"; printf '#!/usr/bin/env bash\nexit 0\n' > "$1/docker"; chmod +x "$1/docker"; }
seed() { # $1=copydir $2=metadir
  hardened_manifest "$1" > "$2/baseline-manifest"
  env GIT_CONFIG_NOSYSTEM=1 GIT_DIR="$2/git" GIT_WORK_TREE="$1" git init -q
  env GIT_CONFIG_NOSYSTEM=1 GIT_DIR="$2/git" GIT_WORK_TREE="$1" git -c core.autocrlf=false -c core.hooksPath=/dev/null -c user.name=r -c user.email=r@l add -Af
  env GIT_CONFIG_NOSYSTEM=1 GIT_DIR="$2/git" GIT_WORK_TREE="$1" git -c core.hooksPath=/dev/null -c user.name=r -c user.email=r@l commit -qm b
}

# 1) ordinary copy must ACCEPT
W="$tmp/ok"; C="$W/pending/proj"; M="$W/pending/proj.meta"; mkdir -p "$C/src" "$M"; mkrsync "$W"
echo code > "$C/main.py"; echo lib > "$C/src/lib.py"; echo "*.log" > "$C/.gitignore"
O="$(mktemp -d)"; cp -a "$C/." "$O/"; printf '%s\n' "$O" > "$M/ORIGINAL"
seed "$C" "$M"; echo improved > "$C/main.py"; echo new > "$C/feature.py"
cp "$ROOT/review" "$W/review"; ln -sf "$ROOT/lib" "$W/lib"; cd "$W"
OUT="$(PATH="$W:$PATH" bash review pending/proj accept <<< yes 2>&1 || true)"
grep -q "now byte-matches the reviewed" <<<"$OUT" || { echo "FAIL: ordinary copy rejected"; echo "$OUT"; exit 1; }
grep -q improved "$O/main.py" && [[ -f "$O/feature.py" && ! -e "$O/.git" ]] || { echo "FAIL: edits not applied cleanly"; exit 1; }
echo "review-accept: ordinary copy accepted, edits applied, .git not transplanted"

# 2) newline-named symlink into .git must BLOCK
W2="$tmp/evil"; C2="$W2/pending/evil"; M2="$W2/pending/evil.meta"; mkdir -p "$C2/.git" "$M2"; mkrsync "$W2"
echo x > "$C2/f"; echo secret > "$C2/.git/config"; O2="$(mktemp -d)"; echo x > "$O2/f"; printf '%s\n' "$O2" > "$M2/ORIGINAL"
seed "$C2" "$M2"; ln -s .git/config "$C2/$(printf 'innocent\nleak')"
cp "$ROOT/review" "$W2/review"; ln -sf "$ROOT/lib" "$W2/lib"; cd "$W2"
OUT2="$(PATH="$W2:$PATH" bash review pending/evil accept <<< yes 2>&1 || true)"
grep -qE "newline or control" <<<"$OUT2" || { echo "FAIL: newline symlink not blocked"; echo "$OUT2"; exit 1; }
grep -q secret "$O2/f" 2>/dev/null && { echo "FAIL: original overwritten"; exit 1; } || true
echo "review-accept: newline symlink into .git blocked, original untouched"

# 4) a valid in-copy symlink must still ACCEPT (guard is not over-broad)
W4="$tmp/validlink"; C4="$W4/pending/proj"; M4="$W4/pending/proj.meta"; mkdir -p "$C4/docs" "$M4"; mkrsync "$W4"
echo real > "$C4/docs/r.md"; O4="$(mktemp -d)"; cp -a "$C4/." "$O4/"; printf '%s\n' "$O4" > "$M4/ORIGINAL"
seed "$C4" "$M4"; ln -s docs/r.md "$C4/link"
cp "$ROOT/review" "$W4/review"; ln -sf "$ROOT/lib" "$W4/lib"; cd "$W4"
OUT4="$(PATH="$W4:$PATH" bash review pending/proj accept <<< yes 2>&1 || true)"
grep -q "now byte-matches" <<<"$OUT4" || { echo "FAIL: valid in-copy symlink blocked"; echo "$OUT4"; exit 1; }
echo "review-accept: valid in-copy symlink accepted"


# 3) absolute and proc-based and .. targets must BLOCK; valid relative .. inside copy must ACCEPT
for L in "/etc/passwd" "/proc/self/cwd/pending/proj/x" ".." "../sib" "sub/../.."; do
  Wx="$(mktemp -d)"; Cx="$Wx/pending/proj"; Mx="$Wx/pending/proj.meta"; mkdir -p "$Cx/sub" "$Mx"; mkrsync "$Wx"
  echo x > "$Cx/f"; Ox="$(mktemp -d)"; echo x > "$Ox/f"; printf '%s\n' "$Ox" > "$Mx/ORIGINAL"
  seed "$Cx" "$Mx"; ln -s "$L" "$Cx/escape"
  cp "$ROOT/review" "$Wx/review"; ln -sf "$ROOT/lib" "$Wx/lib"; cd "$Wx"
  Ox="$(PATH="$Wx:$PATH" bash review pending/proj accept <<< yes 2>&1 || true)"
  grep -qE "absolute|escapes|routes through|unsafe symlink" <<<"$Ox" || { echo "FAIL: symlink $L slipped"; echo "$Ox"; exit 1; }
done
echo "review-accept: absolute, proc, and escaping symlinks blocked"

W5="$tmp/relok"; C5="$W5/pending/proj"; M5="$W5/pending/proj.meta"; mkdir -p "$C5/sub" "$C5/docs" "$M5"; mkrsync "$W5"
echo real > "$C5/docs/r.md"; O5="$(mktemp -d)"; cp -a "$C5/." "$O5/"; printf '%s\n' "$O5" > "$M5/ORIGINAL"
seed "$C5" "$M5"; ln -s ../docs/r.md "$C5/sub/link"
cp "$ROOT/review" "$W5/review"; ln -sf "$ROOT/lib" "$W5/lib"; cd "$W5"
O5o="$(PATH="$W5:$PATH" bash review pending/proj accept <<< yes 2>&1 || true)"
grep -q "now byte-matches" <<<"$O5o" || { echo "FAIL: valid ../docs symlink blocked"; echo "$O5o"; exit 1; }
echo "review-accept: valid relative symlink inside copy accepted"


# 6) .git-routed symlink escape must BLOCK (validation trusts copy .git, accept excludes it)
W6="$tmp/gitroute"; C6="$W6/pending/proj"; M6="$W6/pending/proj.meta"; mkdir -p "$C6" "$M6"; mkrsync "$W6"
echo x > "$C6/f"; O6="$(mktemp -d)"; echo secret > "$O6/secret"; echo x > "$O6/f"; printf '%s\n' "$O6" > "$M6/ORIGINAL"
seed "$C6" "$M6"; ln -s .git/objects/../../../secret "$C6/leak"
cp "$ROOT/review" "$W6/review"; ln -sf "$ROOT/lib" "$W6/lib"; cd "$W6"
O6o="$(PATH="$W6:$PATH" bash review pending/proj accept <<< yes 2>&1 || true)"
grep -qE "routes through .git|escapes" <<<"$O6o" || { echo "FAIL: .git-routed escape slipped"; echo "$O6o"; exit 1; }
grep -q secret "$O6/f" 2>/dev/null && { echo "FAIL: original touched"; exit 1; } || true
echo "review-accept: .git-routed symlink escape blocked"

# 7) resolver is portable: no GNU-only realpath in review
grep -q "realpath -m" "$ROOT/review" && { echo "FAIL: GNU-only realpath -m still present"; exit 1; }
echo "review-accept: portable resolver (no realpath -m)"


# 8) two-link pivot chain must BLOCK (lexical normalization would miss this)
W8="$tmp/pivot"; C8="$W8/pending/proj"; M8="$W8/pending/proj.meta"; mkdir -p "$C8" "$M8"; mkrsync "$W8"
echo x > "$C8/f"; O8="$(mktemp -d)"; echo x > "$O8/f"; printf '%s\n' "$O8" > "$M8/ORIGINAL"
seed "$C8" "$M8"
ln -s . "$C8/pivot"
ln -s pivot/.. "$C8/escape"
cp "$ROOT/review" "$W8/review"; ln -sf "$ROOT/lib" "$W8/lib"; cd "$W8"
O8o="$(PATH="$W8:$PATH" bash review pending/proj accept <<< yes 2>&1 || true)"
grep -qE "escapes|routes through|unsafe symlink" <<<"$O8o" || { echo "FAIL: pivot chain slipped"; echo "$O8o"; exit 1; }
echo "review-accept: pivot/.. two-link chain blocked"

# 9) resolver follows symlink components (uses Path.resolve, not lexical normpath)
grep -q "\.resolve()" "$ROOT/review" || { echo "FAIL: not using Path.resolve"; exit 1; }
echo "review-accept: resolver follows symlink components"


# 10) relative /proc/self/cwd escape must BLOCK (resolves inside at validation, escapes later)
W10="$tmp/proccwd"; C10="$W10/pending/proj"; M10="$W10/pending/proj.meta"; mkdir -p "$C10" "$M10"; mkrsync "$W10"
echo x > "$C10/f"; O10="$(mktemp -d)"; echo x > "$O10/f"; printf '%s\n' "$O10" > "$M10/ORIGINAL"
seed "$C10" "$M10"
ln -s ../../../../../../../../proc/self/cwd/pending/proj/f "$C10/escape"
cp "$ROOT/review" "$W10/review"; ln -sf "$ROOT/lib" "$W10/lib"; cd "$W10"
O10o="$(PATH="$W10:$PATH" bash review pending/proj accept <<< yes 2>&1 || true)"
grep -qE "escapes|unsafe symlink" <<<"$O10o" || { echo "FAIL: relative /proc/self/cwd slipped"; echo "$O10o"; exit 1; }
echo "review-accept: relative /proc/self/cwd escape blocked"

# 11) case-insensitive .git rejection (macOS)
W11="$tmp/gitcase"; C11="$W11/pending/proj"; M11="$W11/pending/proj.meta"; mkdir -p "$C11" "$M11"; mkrsync "$W11"
echo x > "$C11/f"; O11="$(mktemp -d)"; echo x > "$O11/f"; printf '%s\n' "$O11" > "$M11/ORIGINAL"
seed "$C11" "$M11"; ln -s .GIT/config "$C11/leak"
cp "$ROOT/review" "$W11/review"; ln -sf "$ROOT/lib" "$W11/lib"; cd "$W11"
O11o="$(PATH="$W11:$PATH" bash review pending/proj accept <<< yes 2>&1 || true)"
grep -qE "routes through .git|escapes" <<<"$O11o" || { echo "FAIL: .GIT not caught"; echo "$O11o"; exit 1; }
echo "review-accept: case-insensitive .git rejection"

# 12) both containment checks present
grep -q "CHECK 1" "$ROOT/review" && grep -q "CHECK 2" "$ROOT/review" || { echo "FAIL: dual check missing"; exit 1; }
echo "review-accept: dual lexical+resolved containment present"



# 13) locked sessions must NOT create a review copy (no write-back path)
tmp_lock="$(mktemp -d)"
PKG="$tmp_lock/pkg"; cp -a "$ROOT" "$PKG"
cd "$PKG"; cp config.env.example config.env 2>/dev/null || true
mkdir -p auth/gh auth/codex auth/secrets scratch pending
printf t > auth/gh/hosts.yml; printf a > auth/codex/auth.json; printf tok > auth/secrets/claude_setup_token; printf l > auth/STATA.LIC
chmod 600 auth/STATA.LIC auth/secrets/* auth/codex/auth.json 2>/dev/null || true
SRC="$(mktemp -d)"; echo x > "$SRC/f"; (cd "$SRC" && git init -q && git -c user.name=t -c user.email=t@e add -A && git -c user.name=t -c user.email=t@e commit -qm x)
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp_lock/docker"; chmod +x "$tmp_lock/docker"
OUT="$(PATH="$tmp_lock:$PATH" bash go --locked --once codex "$SRC" scan 2>&1 || true)"
[[ -z "$(ls -A pending 2>/dev/null)" ]] || { echo "FAIL: locked session created a pending review copy"; exit 1; }
ls scratch/ 2>/dev/null | grep -q -- "-audit-" || { echo "FAIL: locked session did not create a scratch audit copy"; exit 1; }
echo "review-accept: locked session writes to scratch only, never pending (no write-back)"

# 14) .gitattributes ident filter must NOT hide a byte change (manifest is git-free)
W14="$tmp/ident"; C14="$W14/pending/proj"; M14="$W14/pending/proj.meta"; mkdir -p "$C14" "$M14"; mkrsync "$W14"
printf '#!/bin/sh\n# $Id$\necho hi\n' > "$C14/run.sh"; printf '*.sh ident\n' > "$C14/.gitattributes"
O14="$(mktemp -d)"; cp -a "$C14/." "$O14/"; printf '%s\n' "$O14" > "$M14/ORIGINAL"; seed "$C14" "$M14"
printf '#!/bin/sh\n# $Id: ; HIDDEN ; : $\necho hi\n' > "$C14/run.sh"
cp "$ROOT/review" "$W14/review"; ln -sf "$ROOT/lib" "$W14/lib"; cd "$W14"
SUM="$(PATH="$W14:$PATH" bash review pending/proj 2>&1 || true)"
echo "$SUM" | grep -q "no changes" && { echo "FAIL: ident byte change hidden from summary"; echo "$SUM"; exit 1; }
echo "$SUM" | grep -q "modified" || { echo "FAIL: change not reported as modified"; echo "$SUM"; exit 1; }
echo "review-accept: ident-filter byte change surfaced (manifest is git-free)"

# 15) summary reports correct counts for a plain edit
W15="$tmp/counts"; C15="$W15/pending/proj"; M15="$W15/pending/proj.meta"; mkdir -p "$C15/src" "$M15"; mkrsync "$W15"
echo a > "$C15/main.py"; echo b > "$C15/src/lib.py"; O15="$(mktemp -d)"; cp -a "$C15/." "$O15/"; printf '%s\n' "$O15" > "$M15/ORIGINAL"; seed "$C15" "$M15"
cp "$ROOT/review" "$W15/review"; ln -sf "$ROOT/lib" "$W15/lib"; cd "$W15"
SUM="$(PATH="$W15:$PATH" bash review pending/proj 2>&1 || true)"
echo "$SUM" | grep -q "no changes" || { echo "FAIL: unchanged copy not reported clean"; echo "$SUM"; exit 1; }
echo c > "$C15/main.py"; echo d > "$C15/new.py"
SUM="$(PATH="$W15:$PATH" bash review pending/proj 2>&1 || true)"
echo "$SUM" | grep -q "1 new" && echo "$SUM" | grep -q "1 modified" || { echo "FAIL: edit counts wrong"; echo "$SUM"; exit 1; }
echo "review-accept: summary counts correct (manifest-based)"

# 16) acceptance decision does not use git for changed-detection
grep -q "manifest()" "$ROOT/review" && ! grep -q "diff --cached --shortstat" "$ROOT/review" || { echo "FAIL: still using git shortstat for change decision"; exit 1; }
echo "review-accept: change decision is manifest-based, not git"


# 17) symlink target with a control character is rejected by the manifest (fail closed)
W17="$tmp/ctrltgt"; C17="$W17/pending/proj"; M17="$W17/pending/proj.meta"; mkdir -p "$C17" "$M17"; mkrsync "$W17"
echo x > "$C17/f"; python3 -c "import os; os.symlink('a\tb', '$C17/evil')" 2>/dev/null || true
if [[ -L "$C17/evil" ]]; then
  if ( hardened_manifest "$C17" >/dev/null 2>&1 ); then echo "FAIL: control-char symlink target accepted"; exit 1; fi
  echo "review-accept: control-character symlink target rejected (byte-safe manifest)"
else
  echo "review-accept: (fs would not create control-char symlink; skipped)"
fi

# 17b) REVIEWER CASE: symlink 'safe' -> 'safe\n' must not report "no changes"
W17b="$tmp/nlsym"; C17b="$W17b/pending/proj"; M17b="$W17b/pending/proj.meta"; mkdir -p "$C17b" "$M17b"; mkrsync "$W17b"
ln -s safe "$C17b/link"; O17b="$(mktemp -d)"; cp -a "$C17b/." "$O17b/"; printf '%s\n' "$O17b" > "$M17b/ORIGINAL"; seed "$C17b" "$M17b"
rm "$C17b/link"; python3 -c "import os; os.symlink('safe\n', '$C17b/link')"
cp "$ROOT/review" "$W17b/review"; ln -sf "$ROOT/lib" "$W17b/lib"; cd "$W17b"
SUM="$(PATH="$W17b:$PATH" bash review pending/proj 2>&1 || true)"
echo "$SUM" | grep -q "no changes" && { echo "FAIL: safe -> safe\\\\n reported no changes"; echo "$SUM"; exit 1; }
# acceptance must NOT silently 'apply and verify' a change it didn't see; manifest abort is acceptable too
ACC="$(PATH="$W17b:$PATH" bash review pending/proj accept <<< yes 2>&1 || true)"
echo "$ACC" | grep -q "Applied and verified" && ! grep -q $'safe\n' <(readlink "$O17b/link" 2>/dev/null; printf 'x') && { echo "FAIL: accepted without applying the newline target"; echo "$ACC"; exit 1; } || true
echo "review-accept: safe -> safe+newline symlink is not silently 'no changes'"

# 18) portable hashing: real digest, empty never passes as unchanged
h="$( hardened_hash_file "$ROOT/go" )"
[[ "$h" =~ ^[0-9a-f]{64}$ ]] || { echo "FAIL: hash_file did not produce a digest"; exit 1; }
echo "review-accept: hash_file produces a real digest (no silent empty)"

# 18b) REVIEWER CASE: directory-entry order must not cause false mismatch
DA="$(mktemp -d)"; DB="$(mktemp -d)"
touch "$DA/a" "$DA/b" "$DA/c"; touch "$DB/c" "$DB/a" "$DB/b"
hardened_manifest "$DA" > "$tmp/ma"; hardened_manifest "$DB" > "$tmp/mb"
cmp -s "$tmp/ma" "$tmp/mb" || { echo "FAIL: manifest is order-dependent"; exit 1; }
echo "review-accept: manifest is sorted (order-independent)"

# 19) accept copies a change that preserves size and mtime (--checksum, not -rlt)
W19="$tmp/mtime"; C19="$W19/pending/proj"; M19="$W19/pending/proj.meta"; mkdir -p "$C19" "$M19"; mkrsync "$W19"
printf 'AAAA\n' > "$C19/f.txt"; O19="$(mktemp -d)"; cp -a "$C19/." "$O19/"; printf '%s\n' "$O19" > "$M19/ORIGINAL"; seed "$C19" "$M19"
REF="$O19/f.txt"; printf 'BBBB\n' > "$C19/f.txt"; touch -r "$REF" "$C19/f.txt"
cp "$ROOT/review" "$W19/review"; ln -sf "$ROOT/lib" "$W19/lib"; cd "$W19"
O19o="$(PATH="$W19:$PATH" bash review pending/proj accept <<< yes 2>&1 || true)"
if ! grep -q "BBBB" "$O19/f.txt"; then echo "FAIL: same-size/mtime change not copied"; echo "$O19o"; exit 1; fi
echo "review-accept: same-size/mtime change is copied (checksum-based rsync)"

# 20) source switches present
grep -q -- "--checksum" "$ROOT/review" || { echo "FAIL: accept not using --checksum"; exit 1; }
grep -q "byte-match the copy" "$ROOT/review" || { echo "FAIL: no post-copy verification"; exit 1; }
grep -q "PYMAN" "$ROOT/lib/common.sh" || { echo "FAIL: manifest not implemented in Python"; exit 1; }
echo "review-accept: checksum copy + post-copy verify + Python manifest present"


# 21) host python runs isolated (-I): a hostile hashlib.py in the tree cannot be imported
W21="$tmp/pyiso"; mkdir -p "$W21"
cat > "$W21/hashlib.py" <<PYX
import os
open("$W21/PYPWNED","w").write("x")
PYX
rm -f "$W21/PYPWNED"
( cd "$W21" && hardened_manifest "$W21" >/dev/null 2>&1 ) || true
[[ -e "$W21/PYPWNED" ]] && { echo "FAIL: hostile hashlib.py executed via manifest"; exit 1; }
grep -q "python3 -I" "$ROOT/lib/common.sh" || { echo "FAIL: manifest python not isolated"; exit 1; }
grep -q "python3 -I" "$ROOT/review" || { echo "FAIL: review python not isolated"; exit 1; }
grep -q "python3 -I" "$ROOT/update.sh" || { echo "FAIL: update python not isolated"; exit 1; }
echo "review-accept: host python runs isolated (-I), repo modules cannot hijack import"

echo "review-accept: all pass"
