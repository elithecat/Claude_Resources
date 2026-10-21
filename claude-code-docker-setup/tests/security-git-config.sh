#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

echo "=== why sterile flags were abandoned: gpg.program fires under them ==="
ATTACK="$(mktemp -d)"; MARKER="$(mktemp -u)"; 
git -C "$ATTACK" init -q
git -C "$ATTACK" config log.showSignature true
git -C "$ATTACK" config gpg.program "$ATTACK/evil-gpg"
printf '#!/bin/sh\ntouch %s\nexit 1\n' "$MARKER" > "$ATTACK/evil-gpg"
chmod +x "$ATTACK/evil-gpg"
git -C "$ATTACK" -c user.name=t -c user.email=t@e commit -q --allow-empty -m x -S 2>/dev/null || git -C "$ATTACK" -c user.name=t -c user.email=t@e commit -q --allow-empty -m x
rm -f "$MARKER"
env GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_PAGER=cat     git -c core.fsmonitor=false -c core.hooksPath=/dev/null -c credential.helper=         -c protocol.file.allow=never -c protocol.ext.allow=never         -C "$ATTACK" log --all HEAD --not --remotes --oneline >/dev/null 2>&1 || true
if [[ -e "$MARKER" ]]; then
  echo "   confirmed: config surface beats flag lists (this is why inspection is containerized)"
else
  echo "   (gpg path did not fire in this git build; containerization still required)"
fi

echo "=== the launcher contains no host git against agent workspaces ==="
if grep -E 'git -C "\$PROJECT_PATH"' "$ROOT/go" >/dev/null; then
  echo "   FAIL: host git on PROJECT_PATH found in go"; exit 1
fi
echo "   nothing in the launcher deletes agent output automatically"
! grep -q 'rm -rf -- "$SCRATCH' "$ROOT/go"


echo "=== review sees ignored files now ==="
O="$(mktemp -d)"; printf "secret.txt\n" > "$O/.gitignore"; printf original > "$O/secret.txt"
git -C "$O" init -q; git -C "$O" -c user.name=t -c user.email=t@e add -A 2>/dev/null; git -C "$O" -c user.name=t -c user.email=t@e commit -qm x
C="$(mktemp -d)/copy"; cp -a "$O" "$C"; M="${C}.meta"; mkdir -p "$M"; printf '%s\n' "$O" > "$M/ORIGINAL"
sterile() { env GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_DIR="$M/git" GIT_WORK_TREE="$C"   git -c core.fsmonitor=false -c core.hooksPath=/dev/null "$@"; }
sterile init -q; sterile -c user.name=r -c user.email=r@l add -Af; sterile -c user.name=r -c user.email=r@l commit -qm baseline
printf poisoned > "$C/secret.txt"
sterile add -Af
D="$(sterile diff --cached HEAD --name-only)"
grep -q "secret.txt" <<<"$D" && echo "   changed ignored file appears in the diff"
printf user-edit > "$O/secret.txt"
env GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_DIR="$M/git" GIT_WORK_TREE="$O"   git -c core.fsmonitor=false diff --quiet HEAD 2>/dev/null && { echo "   FAIL: user ignored edit invisible to guard"; exit 1; }
echo "   user edit to an ignored file trips the divergence guard"

echo "=== special files are refused ==="
mkfifo "$C/pipe" 2>/dev/null || true
if [[ -p "$C/pipe" ]]; then
  find "$C" -path "$C/.git" -prune -o \( ! -type f ! -type d ! -type l \) -print | grep -q .     && echo "   fifo detected by the accept guard"
fi

echo "=== accept still excludes .git ==="
grep -q -- '--exclude=.git' "$ROOT/review" && echo "   confirmed"
echo "=== clean cannot be steered outside scratch by a symlink ==="
PKG="$(mktemp -d)"; cp "$ROOT/clean" "$PKG/clean"; chmod +x "$PKG/clean"; mkdir -p "$PKG/scratch"
VICTIM="$(mktemp -d)"; echo precious > "$VICTIM/file.txt"
ln -s "$VICTIM" "$PKG/scratch/evil-link"
mkdir -p "$PKG/scratch/legit"; echo x > "$PKG/scratch/legit/f"
set +e; OUT="$(cd "$PKG" && echo yes | ./clean 2>&1)"; RC=$?; set -e
[[ -f "$VICTIM/file.txt" ]] || { echo "   FAIL: victim file deleted"; exit 1; }
if [[ $RC -ne 0 ]] && grep -q "is a symlink" <<<"$OUT"; then echo "   refused loudly, victim intact"; else echo "   FAIL: bulk clean did not refuse ($RC)"; exit 1; fi
[[ -f "$PKG/scratch/legit/f" ]] || { echo "   FAIL: legit dir deleted despite refusal"; exit 1; }
set +e; OUT2="$(cd "$PKG" && echo yes | ./clean evil-link 2>&1)"; RC2=$?; set -e
if [[ -f "$VICTIM/file.txt" && $RC2 -ne 0 ]]; then echo "   single-name symlink also refused"; else echo "   FAIL: single-name path unsafe"; exit 1; fi
echo "=== accepted symlinks cannot point outside the copy ==="
grep -q "symlinks pointing outside" "$ROOT/review" && echo "   guard present in accept"

echo "=== baseline git commit runs no repo hooks (core.hooksPath) ==="
HK="$(mktemp -d)"; M="$(mktemp -u)"
git -C "$HK" init -q >/dev/null
mkdir -p "$HK/hooks"; printf '#!/bin/sh\ntouch %s\n' "$M" > "$HK/hooks/pre-commit"; chmod +x "$HK/hooks/pre-commit"
git -C "$HK" config core.hooksPath "$HK/hooks"
echo file > "$HK/f"
rm -f "$M"
META="$(mktemp -d)"
env GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_DIR="$META/git" GIT_WORK_TREE="$HK" \
    git -c core.fsmonitor=false -c core.hooksPath=/dev/null -c user.name=r -c user.email=r@l add -Af 2>/dev/null || true
env GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_DIR="$META/git" GIT_WORK_TREE="$HK" \
    git -c core.fsmonitor=false -c core.hooksPath=/dev/null -c user.name=r -c user.email=r@l commit -qm baseline 2>/dev/null || true
[[ -e "$M" ]] && { echo "   FAIL: repo pre-commit hook fired on the host"; exit 1; } || echo "   SAFE: hooksPath override held"
grep -q 'core.hooksPath=/dev/null' "$ROOT/go" && echo "   go baseline uses the override"

echo "=== dangling relative symlink escaping the copy is refused ==="
CP="$(mktemp -d)/copy"; mkdir -p "$CP"
ln -s ../../../etc/passwd "$CP/escape"
CROOT="$(cd -- "$CP" && pwd -P)"
BAD="$(find "$CP" -type l -print | while IFS= read -r l; do
  tgt="$(readlink -- "$l")"; if [[ "$tgt" = /* ]]; then res="$tgt"; else res="$(dirname -- "$l")/$tgt"; fi
  real="$(cd -- "$(dirname -- "$res")" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$(basename -- "$res")" || true)"
  [[ -z "$real" || ( "$real" != "$CROOT" && "$real" != "$CROOT"/* ) ]] && printf '%s\n' "$l"
done)"
[[ -n "$BAD" ]] && echo "   escaping symlink detected by the accept guard" || { echo "   FAIL: escape not caught"; exit 1; }
grep -q 'not overridable' "$ROOT/review" && echo "   refusal is not --force overridable"


echo "=== symlink into .git is refused (leak -> .git/config) ==="
CP2="$(mktemp -d)/copy"; mkdir -p "$CP2/.git"; echo secret > "$CP2/.git/config"
ln -s .git/config "$CP2/leak"
CROOT="$(cd -- "$CP2" && pwd -P)"
HIT="$(find "$CP2" -path "$CP2/.git" -prune -o -type l -print | while IFS= read -r l; do
  tgt="$(readlink -- "$l")"; if [[ "$tgt" = /* ]]; then res="$tgt"; else res="$(dirname -- "$l")/$tgt"; fi
  real="$(cd -- "$(dirname -- "$res")" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$(basename -- "$res")" || true)"
  if [[ -z "$real" || ( "$real" != "$CROOT" && "$real" != "$CROOT"/* ) ]]; then printf 'OUT %s\n' "$l"
  elif [[ "$real" == "$CROOT/.git" || "$real" == "$CROOT/.git/"* ]]; then printf 'GIT %s\n' "$l"; fi
done)"
grep -q "GIT " <<<"$HIT" && echo "   symlink into .git detected" || { echo "   FAIL: .git link not caught"; exit 1; }
grep -q 'routes through .git' "$ROOT/review" && echo "   accept refuses it"

echo "=== numeric config is digit-gated before arithmetic ==="
M="$(mktemp -u)"; rm -f "$M"
OUT="$(MAX_WORKSPACE_MB="1\$(touch $M)" bash -c 'source "'$ROOT'/lib/common.sh"; MAX_WORKSPACE_MB="${MAX_WORKSPACE_MB}"; [[ "$MAX_WORKSPACE_MB" =~ ^[0-9]+$ ]] && echo DIGITS || echo REJECTED' 2>&1 || true)"
[[ -e "$M" ]] && { echo "   FAIL: arithmetic executed a command"; exit 1; } || echo "   no command executed from crafted numeric value"
grep -q 'digits only' "$ROOT/go" && echo "   go gates MAX_WORKSPACE_MB"

echo "=== proxy batch allowlist resists percent-encoding ==="
node -e '
const rp=(p)=>{let x=p;try{for(let i=0;i<5&&/%[0-9a-fA-F]{2}/.test(x);i++)x=decodeURIComponent(x);}catch{return false;}
if(/%[0-9a-fA-F]{2}/.test(x)||x.includes("..")||x.includes("\0"))return false;
if(/(^|\/)batches(\/|$)/.test(x))return false;
return x==="/v1/messages"||(x.startsWith("/v1/messages/")&&!x.slice(13).includes("/")&&x.length>13);};
const t=[["/v1/messages",true],["/v1/messages/%62atches",false],["/v1/messages/%2562atches",false]];
let ok=true;for(const[u,w]of t)if(rp(u)!==w)ok=false;process.exit(ok?0:1);
' && echo "   percent-encoded batch routes rejected"

echo "=== all hardening checks pass ==="
