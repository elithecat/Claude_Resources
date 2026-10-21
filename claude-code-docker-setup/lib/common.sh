#!/usr/bin/env bash
# Shared launcher helpers. Top-level scripts source this file.
# shellcheck shell=bash
# shellcheck disable=SC2034

hardened_die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

hardened_warn() {
    printf 'Warning: %s\n' "$*" >&2
}

hardened_note() {
    printf '%s\n' "$*"
}

hardened_require_command() {
    command -v "$1" >/dev/null 2>&1 || hardened_die "required command not found: $1"
}

hardened_trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

# Parse a small KEY=value file as data. It is never sourced or evaluated.
# Existing environment values take precedence over config.env.
hardened_load_config() {
    local file="$1" line key value lineno=0
    [[ -f "$file" ]] || return 0
    [[ ! -L "$file" ]] || hardened_die "refusing symbolic-link config file: $file"

    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno + 1))
        line="${line%$'\r'}"
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" == *=* ]] || hardened_die "$file:$lineno: expected KEY=value"

        key="$(hardened_trim "${line%%=*}")"
        value="${line#*=}"

        case "$key" in
            IMAGE_NAME|PROXY_IMAGE_NAME|AGENT_VERSION|CODEX_VERSION|CLAUDE_VERSION|STATA_IMAGE|STATA_EDITION|GIT_USER_NAME|GIT_USER_EMAIL|MEMORY_LIMIT|CPU_LIMIT|PIDS_LIMIT|SHM_SIZE|PLATFORM|PROXY_MAX_REQUESTS_INTERACTIVE|PROXY_MAX_REQUESTS_AUTONOMOUS|MAX_WORKSPACE_MB|CLAUDE_MODEL) ;;
            *) hardened_die "$file:$lineno: unsupported setting: $key" ;;
        esac

        [[ "$key" =~ ^[A-Z][A-Z0-9_]*$ ]] || hardened_die "$file:$lineno: invalid key"
        [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || hardened_die "$file:$lineno: multiline values are not allowed"

        # Treat an empty environment value as unset. printf -v is available in
        # macOS Bash 3.2 and assigns globally because the target key is not local.
        if [[ -z "${!key-}" ]]; then
            printf -v "$key" '%s' "$value"
            export "${key?}"
        fi
    done < "$file"
}

hardened_validate_text_setting() {
    local label="$1" value="$2"
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || hardened_die "$label must not contain a newline"
}

hardened_validate_common_config() {
    local __n
    for __n in PIDS_LIMIT MEMORY_LIMIT CPU_LIMIT SHM_SIZE PROXY_MAX_REQUESTS_INTERACTIVE PROXY_MAX_REQUESTS_AUTONOMOUS MAX_WORKSPACE_MB; do
        case "$__n" in
            MEMORY_LIMIT|SHM_SIZE) [[ "${!__n-}" =~ ^[0-9]+[kmgKMG]?$ || -z "${!__n-}" ]] || hardened_die "$__n must be a size like 512m or 16g" ;;
            CPU_LIMIT) [[ "${!__n-}" =~ ^[0-9]+(\.[0-9]+)?$ || -z "${!__n-}" ]] || hardened_die "$__n must be numeric" ;;
            *) [[ "${!__n-}" =~ ^[0-9]+$ || -z "${!__n-}" ]] || hardened_die "$__n must be digits only" ;;
        esac
    done
    local label
    for label in IMAGE_NAME PROXY_IMAGE_NAME AGENT_VERSION STATA_IMAGE STATA_EDITION GIT_USER_NAME GIT_USER_EMAIL MEMORY_LIMIT CPU_LIMIT PIDS_LIMIT SHM_SIZE PLATFORM PROXY_MAX_REQUESTS_INTERACTIVE PROXY_MAX_REQUESTS_AUTONOMOUS; do
        hardened_validate_text_setting "$label" "${!label-}"
    done

    [[ "$IMAGE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._/:@-]*$ ]] || hardened_die "IMAGE_NAME contains unsupported characters"
    [[ "$PROXY_IMAGE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._/:@-]*$ ]] || hardened_die "PROXY_IMAGE_NAME contains unsupported characters"
    [[ "$STATA_IMAGE" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*@sha256:[0-9a-f]{64}$ ]] || hardened_die "STATA_IMAGE must be pinned to a full sha256 digest"
    [[ "$AGENT_VERSION" =~ ^[0-9]+([.][0-9]+){1,3}([A-Za-z0-9._-]*)?$ ]] || hardened_die "AGENT_VERSION must be a pinned version"
    # Stata's Linux binaries in this image are amd64-only. Accepting an arbitrary
    # platform would produce an image that builds inconsistently or cannot run Stata.
    # shellcheck disable=SC2153
    [[ "$PLATFORM" == "linux/amd64" ]] || hardened_die "PLATFORM must be linux/amd64 for this Stata image"
    [[ "$MEMORY_LIMIT" =~ ^[1-9][0-9]*([kKmMgGtT])?$ ]] || hardened_die "MEMORY_LIMIT must look like 8g or 16384m"
    [[ "$SHM_SIZE" =~ ^[1-9][0-9]*([kKmMgGtT])?$ ]] || hardened_die "SHM_SIZE must look like 1g or 512m"
    [[ "$CPU_LIMIT" =~ ^([1-9][0-9]*|0[.][0-9]+|[1-9][0-9]*[.][0-9]+)$ ]] || hardened_die "CPU_LIMIT must be greater than zero"
    [[ "$PIDS_LIMIT" =~ ^[1-9][0-9]*$ ]] || hardened_die "PIDS_LIMIT must be a positive integer"
    [[ "$PROXY_MAX_REQUESTS_INTERACTIVE" =~ ^[1-9][0-9]*$ ]] || hardened_die "PROXY_MAX_REQUESTS_INTERACTIVE must be positive"
    [[ "$PROXY_MAX_REQUESTS_AUTONOMOUS" =~ ^[1-9][0-9]*$ ]] || hardened_die "PROXY_MAX_REQUESTS_AUTONOMOUS must be positive"
    case "$STATA_EDITION" in se|mp|be) ;; *) hardened_die "STATA_EDITION must be se, mp, or be" ;; esac
}

hardened_validate_port_offset() {
    local raw="$1"
    [[ "$raw" =~ ^[0-9]{1,5}$ ]] || hardened_die "port offset must be a non-negative decimal integer"
    # Validation happens before arithmetic; 10# prevents octal interpretation.
    PORT_OFFSET=$((10#$raw))
    (( PORT_OFFSET <= 56647 )) || hardened_die "port offset is too large; 8888 + offset must be at most 65535"
}

hardened_hash_text() {
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$1" | sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
    else
        hardened_die "sha256sum or shasum is required"
    fi
}

# SHA-256 of a file's raw bytes. Portable (sha256sum or shasum) and FAILS CLOSED:
# if neither tool exists or the hash cannot be computed, it dies rather than
# returning an empty string that a diff would read as "unchanged".
hardened_hash_file() {
    local f="$1" h=''
    if command -v sha256sum >/dev/null 2>&1; then
        h="$(sha256sum -- "$f" 2>/dev/null | cut -d' ' -f1)"
    elif command -v shasum >/dev/null 2>&1; then
        h="$(shasum -a 256 -- "$f" 2>/dev/null | awk '{print $1}')"
    else
        hardened_die "sha256sum or shasum is required to hash files"
    fi
    [[ "$h" =~ ^[0-9a-f]{64}$ ]] || hardened_die "failed to hash $f (empty or malformed digest)"
    printf '%s' "$h"
}

# Byte-safe filesystem manifest of a directory, implemented entirely in Python so
# that (a) a trailing newline in a symlink target is preserved rather than eaten
# by shell command substitution, (b) records are sorted by raw path bytes so
# directory-entry order can't cause false mismatches, and (c) ANY error (missing
# hasher, unreadable file, control byte in a target) aborts the whole manifest
# instead of silently recording an empty digest. Output is NUL-delimited records
# of NUL-separated fields; git is never consulted, so repo .gitattributes cannot
# hide a change.
hardened_manifest() {
    python3 -I - "$1" <<'PYMAN'
import os, sys, hashlib
root = sys.argv[1]

def die(msg):
    sys.stderr.write("manifest error: %s\n" % msg)
    sys.exit(1)

records = []  # (raw_path_bytes, full_record_bytes)

def walk(dirpath, relparts):
    try:
        entries = sorted(os.listdir(dirpath))
    except OSError as e:
        die("cannot list %r: %s" % (dirpath, e))
    for name in entries:
        rel = relparts + [name]
        # Skip .git at ANY depth, matching rsync's --exclude=.git used at accept
        # time (rsync patterns without a leading slash match at every level).
        # A mismatch here made post-copy verification fail on any repo containing
        # a nested .git (submodule, vendored checkout, worktree pointer file).
        if name == ".git":
            continue
        full = os.path.join(dirpath, name)
        relpath = "/".join(rel).encode("utf-8", "surrogateescape")
        # No control bytes anywhere in a path or (below) a symlink target.
        if any(b < 0x20 or b == 0x7f for b in relpath):
            die("control byte in path: %r" % relpath)
        try:
            st = os.lstat(full)
        except OSError as e:
            die("cannot stat %r: %s" % (full, e))
        import stat as _stat
        mode = st.st_mode
        if _stat.S_ISLNK(mode):
            try:
                tgt = os.readlink(full)
            except OSError as e:
                die("cannot readlink %r: %s" % (full, e))
            tgtb = tgt.encode("utf-8", "surrogateescape")
            if any(b < 0x20 or b == 0x7f for b in tgtb):
                die("control byte in symlink target: %r" % relpath)
            records.append((relpath, b"l\0" + relpath + b"\0" + tgtb + b"\0"))
        elif _stat.S_ISDIR(mode):
            records.append((relpath, b"d\0" + relpath + b"\0\0"))
            walk(full, rel)
        elif _stat.S_ISREG(mode):
            h = hashlib.sha256()
            try:
                with open(full, "rb") as fh:
                    for chunk in iter(lambda: fh.read(1 << 20), b""):
                        h.update(chunk)
            except OSError as e:
                die("cannot read %r: %s" % (full, e))
            records.append((relpath, b"f\0" + relpath + b"\0" + h.hexdigest().encode() + b"\0"))
        else:
            records.append((relpath, b"s\0" + relpath + b"\0\0"))

if not os.path.isdir(root):
    die("not a directory: %r" % root)
walk(root, [])
records.sort(key=lambda r: r[0])
out = getattr(sys.stdout, "buffer", sys.stdout)
for _, rec in records:
    out.write(rec)
PYMAN
    local rc=$?
    (( rc == 0 )) || hardened_die "manifest generation failed"
}

hardened_reject_symlink_components() {
    local path="$1" label="${2:-path}" current='' rest component
    [[ "$path" == /* ]] || hardened_die "$label must be an absolute path: $path"

    # Avoid an intermediate array here. macOS ships Bash 3.2, where expanding
    # an empty array while `set -u` is active can raise "unbound variable".
    rest="${path#/}"
    while [[ -n "$rest" ]]; do
        if [[ "$rest" == */* ]]; then
            component="${rest%%/*}"
            rest="${rest#*/}"
        else
            component="$rest"
            rest=''
        fi
        [[ -n "$component" ]] || continue
        current="$current/$component"
        [[ ! -L "$current" ]] || hardened_die "refusing $label with symbolic-link component: $current"
    done
}

hardened_ensure_private_dir() {
    local dir="$1"
    [[ "$dir" == /* ]] || hardened_die "private directory path must be absolute: $dir"
    hardened_reject_symlink_components "$dir" "private directory"
    mkdir -p -- "$dir"
    hardened_reject_symlink_components "$dir" "private directory"
    [[ -d "$dir" && ! -L "$dir" ]] || hardened_die "could not create a safe directory: $dir"
    chmod 700 -- "$dir" 2>/dev/null || true
}

hardened_canonical_dir() {
    local path="$1"
    [[ -d "$path" ]] || hardened_die "directory not found: $path"
    (cd -- "$path" && pwd -P)
}

hardened_validate_project_path() {
    local script_dir="$1" project="$2" home_dir="${HOME:-}"
    [[ "$project" == /* ]] || hardened_die "project path did not resolve to an absolute path"
    [[ "$project" != *','* && "$project" != *$'\n'* && "$project" != *$'\r'* ]] || hardened_die "project path contains an unsupported character"
    [[ "$project" != / ]] || hardened_die "refusing to mount the host root directory"
    if [[ -n "$home_dir" ]]; then
        home_dir="$(hardened_canonical_dir "$home_dir")"
        [[ "$project" != "$home_dir" ]] || hardened_die "refusing to mount the entire home directory"
    fi

    case "$project/" in
        "$script_dir/auth/"*|"$script_dir/state/"*) hardened_die "refusing to use credentials or runtime state as a project" ;;
    esac
    case "$script_dir/auth/" in
        "$project/"*) hardened_die "project path would expose the setup credential directory" ;;
    esac
}

hardened_is_public_github_url() {
    [[ "$1" =~ ^https://github[.]com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+([.]git)?/?$ ]]
}

hardened_normalize_github_url() {
    local url="${1%/}"
    hardened_is_public_github_url "$url" || return 1
    url="${url%.git}.git"
    printf '%s' "$url"
}

hardened_github_repo_path() {
    local url
    url="$(hardened_normalize_github_url "$1")" || return 1
    printf '%s' "${url#https://github.com}"
}

# Run git against a possibly-hostile checkout with all repo-controlled execution
# vectors neutralized (hooks, fsmonitor, credential/askpass, ext/file protocols,
# system/global config). Used by scratch-cleanup checks, which must inspect a
# freshly cloned repo without letting it run code. Never use bare `git -C
# "$PROJECT_PATH"` on a scratch or audit checkout.
hardened_sterile_git() {
    local project="$1"; shift
    GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null \
    GIT_TERMINAL_PROMPT=0 \
    GIT_ASKPASS=/bin/false \
    git -C "$project" \
        -c core.hooksPath=/dev/null \
        -c core.fsmonitor=false \
        -c credential.helper= \
        -c protocol.file.allow=never \
        -c protocol.ext.allow=never \
        "$@"
}

# Decide whether a scratch clone holds work that is NOT safely on a remote.
# Prints a short reason if it should be KEPT, or nothing if it is safe to delete.
hardened_scratch_unsaved_reason() {
    local project="$1"
    [[ -d "$project/.git" ]] || { printf 'not a git repo'; return; }
    if [[ -n "$(hardened_sterile_git "$project" status --porcelain 2>/dev/null)" ]]; then
        printf 'uncommitted changes'; return
    fi
    if hardened_sterile_git "$project" remote 2>/dev/null | grep -q .; then
        if [[ -n "$(hardened_sterile_git "$project" log --branches --not --remotes --oneline 2>/dev/null | head -1)" ]]; then
            printf 'unpushed commits'; return
        fi
    else
        if [[ -n "$(hardened_sterile_git "$project" log --oneline -1 2>/dev/null)" ]]; then
            printf 'commits with no remote'; return
        fi
    fi
    # nothing printed: safe to delete
}

# Resolve a local checkout's origin without executing repository hooks or
# credential helpers. A non-GitHub or missing origin simply disables the
# in-container push proxy for that run.
hardened_detect_github_origin() {
    local project="$1" url
    command -v git >/dev/null 2>&1 || return 1
    url="$(
        GIT_CONFIG_NOSYSTEM=1 \
        GIT_CONFIG_GLOBAL=/dev/null \
        GIT_TERMINAL_PROMPT=0 \
        GIT_ASKPASS=/bin/false \
        git -C "$project" \
            -c core.hooksPath=/dev/null \
            -c core.fsmonitor=false \
            -c credential.helper= \
            -c protocol.file.allow=never \
            -c protocol.ext.allow=never \
            remote get-url origin 2>/dev/null || true
    )"
    [[ -n "$url" && "$url" != *$'\n'* && "$url" != *$'\r'* ]] || return 1
    hardened_normalize_github_url "$url"
}

# Resolve the checked-out branch without running hooks or credential helpers.
# Detached HEAD checkouts can still work, but do not receive a push capability.
hardened_current_branch() {
    local project="$1" branch
    command -v git >/dev/null 2>&1 || return 1
    branch="$(
        GIT_CONFIG_NOSYSTEM=1 \
        GIT_CONFIG_GLOBAL=/dev/null \
        GIT_TERMINAL_PROMPT=0 \
        GIT_ASKPASS=/bin/false \
        git -C "$project" \
            -c core.hooksPath=/dev/null \
            -c core.fsmonitor=false \
            -c credential.helper= \
            -c protocol.file.allow=never \
            -c protocol.ext.allow=never \
            symbolic-ref --quiet --short HEAD 2>/dev/null || true
    )"
    [[ -n "$branch" && "$branch" != *$'\n'* && "$branch" != *$'\r'* ]] || return 1
    hardened_validate_branch "$branch"
    printf '%s' "$branch"
}

hardened_validate_branch() {
    local branch="$1"
    [[ -n "$branch" ]] || return 0
    # Conservative host-side validation; the isolated Git helper also runs
    # git check-ref-format before clone/publish.
    [[ ${#branch} -le 255 ]] || hardened_die "Git branch name is too long"
    [[ "$branch" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || hardened_die "invalid Git branch name: $branch"
    [[ "$branch" != *'..'* && "$branch" != *'//'* && "$branch" != *'@{'* ]] || hardened_die "invalid Git branch name: $branch"
    [[ "$branch" != */ && "$branch" != *. && "$branch" != *.lock && "$branch" != *'/.lock' ]] || hardened_die "invalid Git branch name: $branch"
}

hardened_repo_slug() {
    local value="${1%/}" slug
    value="${value%.git}"
    slug="${value##*/}"
    slug="$(printf '%s' "$slug" | tr -c 'A-Za-z0-9._-' '-')"
    [[ -n "$slug" ]] || slug=repository
    printf '%s' "$slug"
}

hardened_clone_public_repo() {
    local image="$1" platform="$2" url="$3" branch="$4" worktrees_root="$5"
    local slug stamp leaf destination uid gid
    hardened_is_public_github_url "$url" || hardened_die "URL mode accepts public HTTPS GitHub URLs only; use clone-private.sh for a private repository"
    hardened_validate_branch "$branch"
    hardened_require_command docker
    hardened_ensure_private_dir "$worktrees_root"

    slug="$(hardened_repo_slug "$url")"
    stamp="$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM}"
    leaf="${slug}-${stamp}"
    destination="$worktrees_root/$leaf"
    mkdir -m 700 -- "$destination"

    hardened_resolve_host_identity
    uid="$HARDENED_HOST_UID"
    gid="$HARDENED_HOST_GID"
    if [[ "$(id -u)" == 0 ]]; then
        chown "$uid:$gid" "$destination"
    fi

    # The helper receives one empty destination, not the worktrees parent. A
    # malicious checkout therefore cannot inspect or alter earlier clones.
    if ! docker run --rm \
        --platform "$platform" \
        --user "$uid:$gid" \
        --init \
        --read-only \
        --cap-drop=ALL \
        --security-opt=no-new-privileges:true \
        --pids-limit 128 \
        --memory 1g \
        --cpus 1 \
        --tmpfs "/tmp:rw,exec,nosuid,nodev,size=512m,uid=$uid,gid=$gid" \
        --tmpfs "/home/helper:rw,nosuid,nodev,size=64m,uid=$uid,gid=$gid" \
        --mount "type=bind,src=$destination,dst=/worktree" \
        -e HOME=/home/helper \
        --entrypoint /opt/agent/github-helper \
        "$image" clone-public "$url" /worktree "$branch"; then
        rm -rf -- "$destination"
        hardened_die "public repository clone failed"
    fi

    printf '%s' "$destination"
}

hardened_project_state_dir() {
    local script_dir="$1" project_path="$2" key state
    key="$(hardened_hash_text "$project_path")"
    key="${key:0:20}"
    state="$script_dir/state/projects/$key"
    hardened_ensure_private_dir "$script_dir/state"
    hardened_ensure_private_dir "$script_dir/state/projects"
    hardened_ensure_private_dir "$state"
    hardened_ensure_private_dir "$state/R"
    hardened_ensure_private_dir "$state/python"
    hardened_ensure_private_dir "$state/stata-ado"
    hardened_ensure_private_dir "$state/outputs"
    printf '%s' "$state"
}

hardened_make_run_tmp() {
    local script_dir="$1"
    hardened_ensure_private_dir "$script_dir/state"
    hardened_ensure_private_dir "$script_dir/state/tmp"
    mktemp -d "$script_dir/state/tmp/run.XXXXXXXX"
}

hardened_make_gitconfig() {
    local file="$1"
    # Commit identity is supplied through GIT_AUTHOR_* and GIT_COMMITTER_*.
    # Keeping this file static avoids parsing user-controlled identity text.
    cat > "$file" <<'EOF_GITCONFIG'
[init]
    defaultBranch = main
[safe]
    directory = /workspace
[commit]
    gpgSign = false
[tag]
    gpgSign = false
[core]
    hooksPath = /dev/null
    fsmonitor = false
    sshCommand = /bin/false
[credential]
    helper =
[protocol "file"]
    allow = never
[protocol "ext"]
    allow = never
[gpg]
    program = /bin/false
[log]
    showSignature = false
EOF_GITCONFIG
    chmod 600 "$file"
}

hardened_secret_file() {
    local file="$1" label="$2"
    [[ "$file" == /* ]] || hardened_die "$label path must be absolute: $file"
    hardened_reject_symlink_components "$file" "$label path"
    [[ -f "$file" && ! -L "$file" && -s "$file" ]] || hardened_die "$label is not configured: $file"
    chmod 600 "$file" 2>/dev/null || true
    printf '%s' "$file"
}

hardened_dir_has_files() {
    local dir="$1" entry base
    [[ -d "$dir" ]] || return 1
    for entry in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
        [[ -e "$entry" ]] || continue
        base="${entry##*/}"
        [[ "$base" == .gitkeep ]] && continue
        return 0
    done
    return 1
}

hardened_resolve_host_identity() {
    local id_command uid gid
    if [[ -x /usr/bin/id ]]; then id_command=/usr/bin/id
    elif [[ -x /bin/id ]]; then id_command=/bin/id
    else hardened_die "trusted system id command was not found"
    fi
    uid="$($id_command -u)"
    gid="$($id_command -g)"
    [[ "$uid" != 0 ]] || hardened_die "do not run this launcher as root; use a non-root account with Docker access"
    [[ "$uid" =~ ^[1-9][0-9]*$ && "$gid" =~ ^[0-9]+$ ]] || hardened_die "could not determine a safe non-root host UID/GID"
    HARDENED_HOST_UID="$uid"
    HARDENED_HOST_GID="$gid"
    export HARDENED_HOST_UID HARDENED_HOST_GID
}

hardened_build_security_args() {
    local uid gid
    hardened_resolve_host_identity
    uid="$HARDENED_HOST_UID"
    gid="$HARDENED_HOST_GID"

    # The container is the sole security boundary: the agents are configured NOT
    # to run their own inner sandboxes (Codex sandbox_mode=danger-full-access in
    # the baked config; Claude Code launched without CLAUDE_CODE_SANDBOXED), so
    # the container can stay fully hardened in every mode rather than being
    # loosened to permit nested user namespaces.
    # shellcheck disable=SC2034 # consumed by the sourcing launcher
    SECURITY_ARGS=(
        --init
        --read-only
        --user "$uid:$gid"
        --cap-drop=ALL
        --security-opt=no-new-privileges:true
        --pids-limit "$PIDS_LIMIT"
        --memory "$MEMORY_LIMIT"
        --cpus "$CPU_LIMIT"
        --shm-size "$SHM_SIZE"
        --ulimit core=0
        --tmpfs "/tmp:rw,exec,nosuid,nodev,size=2g,uid=$uid,gid=$gid"
        --tmpfs "/var/tmp:rw,exec,nosuid,nodev,size=1g,uid=$uid,gid=$gid"
        --tmpfs "/run:rw,nosuid,nodev,size=64m,uid=$uid,gid=$gid"
        --tmpfs "/home/$AGENT_USER:rw,exec,nosuid,nodev,size=2g,uid=$uid,gid=$gid,mode=0700"
        --workdir /workspace
    )
}

hardened_add_git_environment() {
    # shellcheck disable=SC2034 # consumed by the sourcing launcher
    GIT_ENV_ARGS=(
        -e "GIT_AUTHOR_NAME=$GIT_USER_NAME"
        -e "GIT_AUTHOR_EMAIL=$GIT_USER_EMAIL"
        -e "GIT_COMMITTER_NAME=$GIT_USER_NAME"
        -e "GIT_COMMITTER_EMAIL=$GIT_USER_EMAIL"
        -e GIT_CONFIG_SYSTEM=/etc/agent-gitconfig
        -e GIT_CONFIG_GLOBAL=/dev/null
        -e GIT_TERMINAL_PROMPT=0
        -e GIT_ASKPASS=/bin/false
        -e SSH_ASKPASS=/bin/false
        -e GIT_LFS_SKIP_SMUDGE=1
        -e GIT_CONFIG_COUNT=8
        -e GIT_CONFIG_KEY_0=core.hooksPath
        -e GIT_CONFIG_VALUE_0=/dev/null
        -e GIT_CONFIG_KEY_1=credential.helper
        -e GIT_CONFIG_VALUE_1=
        -e GIT_CONFIG_KEY_2=protocol.file.allow
        -e GIT_CONFIG_VALUE_2=never
        -e GIT_CONFIG_KEY_3=protocol.ext.allow
        -e GIT_CONFIG_VALUE_3=never
        -e GIT_CONFIG_KEY_4=core.fsmonitor
        -e GIT_CONFIG_VALUE_4=false
        -e GIT_CONFIG_KEY_5=core.sshCommand
        -e GIT_CONFIG_VALUE_5=/bin/false
        -e GIT_CONFIG_KEY_6=commit.gpgSign
        -e GIT_CONFIG_VALUE_6=false
        -e GIT_CONFIG_KEY_7=tag.gpgSign
        -e GIT_CONFIG_VALUE_7=false
    )
}

# Add a command-scope push URL and client header without changing the worktree's
# .git/config. The reusable GitHub token remains in the dedicated proxy sidecar.

PROXY_CONTAINER=''
PROXY_INTERNAL_NETWORK=''
PROXY_EGRESS_NETWORK=''
DIRECT_AGENT_NETWORK=''
PROXY_CLIENT_TOKEN=''
PROXY_CLIENT_FILE=''
GITHUB_PUSH_CONTAINER=''
GITHUB_PUSH_NETWORK=''
GITHUB_PUSH_QUEUE=''
GITHUB_PUSH_REPO_URL=''
GITHUB_PUSH_BRANCH=''
# Exported because launchers consume these values after sourcing this helper.
export AGENT_NETWORK=''
export PROXY_CLIENT_TOKEN
export GITHUB_PUSH_QUEUE GITHUB_PUSH_REPO_URL GITHUB_PUSH_BRANCH
AGENT_NETWORK_DOCKER_ARGS=()
PROXY_INTERNAL_IP=''

hardened_random_hex() {
    local bytes="${1:-32}" value
    [[ "$bytes" =~ ^[1-9][0-9]*$ ]] || hardened_die "random byte count must be positive"
    if command -v openssl >/dev/null 2>&1; then
        value="$(openssl rand -hex "$bytes")"
    elif [[ -r /dev/urandom ]] && command -v od >/dev/null 2>&1; then
        value="$(LC_ALL=C od -An -N "$bytes" -tx1 /dev/urandom | tr -d ' \n')"
    else
        hardened_die "openssl or /dev/urandom plus od is required to create a per-run proxy credential"
    fi
    [[ "$value" =~ ^[0-9a-f]+$ ]] || hardened_die "could not create a valid random credential"
    (( ${#value} == bytes * 2 )) || hardened_die "could not create a valid random credential"
    printf '%s' "$value"
}

hardened_start_direct_agent_network() {
    local suffix
    [[ -z "$DIRECT_AGENT_NETWORK" && -z "$AGENT_NETWORK" ]] || hardened_die "agent network is already active"
    suffix="$(date +%s)-$$-${RANDOM}"
    DIRECT_AGENT_NETWORK="hardened-agent-egress-$suffix"
    docker network create --driver bridge --label agents.proxy=1 "$DIRECT_AGENT_NETWORK" >/dev/null
    AGENT_NETWORK="$DIRECT_AGENT_NETWORK"
    AGENT_NETWORK_DOCKER_ARGS=(--network "$AGENT_NETWORK")
    export AGENT_NETWORK
}

# Start a generic authenticated CONNECT proxy that permits only OpenAI/ChatGPT
# provider domains. This lets Codex use ChatGPT subscription authentication
# while the agent container itself remains on a Docker-internal network.
hardened_start_codex_egress_proxy() {
    local proxy_image="$1" max_requests="$2" suffix uid gid proxy_ip attempt
    [[ "$max_requests" =~ ^[1-9][0-9]*$ ]] || hardened_die "invalid Codex egress proxy request limit"
    [[ -z "$PROXY_CONTAINER" && -z "$AGENT_NETWORK" ]] || hardened_die "agent proxy/network is already active"

    suffix="$(date +%s)-$$-${RANDOM}"
    PROXY_CONTAINER="hardened-codex-egress-$suffix"
    PROXY_EGRESS_NETWORK="hardened-egress-$suffix"
    PROXY_INTERNAL_NETWORK="hardened-internal-$suffix"
    hardened_resolve_host_identity
    uid="$HARDENED_HOST_UID"
    gid="$HARDENED_HOST_GID"

    PROXY_CLIENT_TOKEN="$(hardened_random_hex 32)"
    PROXY_CLIENT_FILE="$(mktemp "${TMPDIR:-/tmp}/hardened-codex-egress.XXXXXXXX")"
    printf '%s\n' "$PROXY_CLIENT_TOKEN" > "$PROXY_CLIENT_FILE"
    chmod 600 "$PROXY_CLIENT_FILE"
    export PROXY_CLIENT_TOKEN

    docker network create --driver bridge --label agents.proxy=1 "$PROXY_EGRESS_NETWORK" >/dev/null
    if ! docker network create --driver bridge --internal --label agents.proxy=1 \
        -o com.docker.network.bridge.gateway_mode_ipv4=isolated "$PROXY_INTERNAL_NETWORK" >/dev/null 2>&1; then
        hardened_die "locked mode needs Docker isolated gateway mode, which this engine lacks; upgrade Docker or run this audit on a host that supports it"
    fi

    docker run -d \
        --label agents.proxy=1 \
        --name "$PROXY_CONTAINER" \
        --platform "$PLATFORM" \
        --label hardened.component=codex-provider-egress-proxy \
        --network "$PROXY_EGRESS_NETWORK" \
        --network-alias codex-egress \
        --user "$uid:$gid" \
        --init \
        --read-only \
        --cap-drop=ALL \
        --security-opt=no-new-privileges:true \
        --pids-limit 64 \
        --memory 256m \
        --cpus 0.5 \
        --tmpfs "/tmp:rw,nosuid,nodev,size=32m,uid=$uid,gid=$gid" \
        --tmpfs "/run:rw,nosuid,nodev,size=16m,uid=$uid,gid=$gid" \
        --mount "type=bind,src=$PROXY_CLIENT_FILE,dst=/run/secrets/client_credential,readonly" \
        -e "EGRESS_PROXY_MAX_REQUESTS=$max_requests" \
        --entrypoint node \
        "$proxy_image" /opt/proxy/codex-egress-proxy.mjs >/dev/null

    docker network connect --alias codex-egress "$PROXY_INTERNAL_NETWORK" "$PROXY_CONTAINER"
    AGENT_NETWORK="$PROXY_INTERNAL_NETWORK"
    proxy_ip="$(docker inspect --format "{{(index .NetworkSettings.Networks \"$PROXY_INTERNAL_NETWORK\").IPAddress}}" "$PROXY_CONTAINER")"
    [[ "$proxy_ip" =~ ^[0-9]+([.][0-9]+){3}$ ]] || hardened_die "could not determine the Codex egress proxy IP"
    AGENT_NETWORK_DOCKER_ARGS=(
        --network "$AGENT_NETWORK"
        --dns 192.0.2.53
        --add-host "codex-egress:$proxy_ip"
    )
    export AGENT_NETWORK

    for ((attempt = 0; attempt < 60; attempt++)); do
        if docker exec "$PROXY_CONTAINER" node -e \
            'fetch("http://127.0.0.1:8082/healthz").then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))' \
            >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.25
    done

    docker inspect --format 'Codex egress proxy state={{.State.Status}} exit={{.State.ExitCode}} error={{.State.Error}}' "$PROXY_CONTAINER" >&2 || true
    docker logs "$PROXY_CONTAINER" >&2 || true
    hardened_die "Codex provider egress proxy did not become healthy"
}

hardened_start_proxy() {
    local mode="$1" secret_file="$2" proxy_image="$3" allow_agent_egress="$4" max_requests="$5"
    local suffix uid gid

    case "$mode" in anthropic-api-key|anthropic-oauth|openai-api-key) ;; *) hardened_die "unsupported proxy mode: $mode" ;; esac
    [[ -f "$secret_file" && ! -L "$secret_file" ]] || hardened_die "invalid proxy secret file"
    [[ "$max_requests" =~ ^[1-9][0-9]*$ ]] || hardened_die "invalid proxy request limit"

    suffix="$(date +%s)-$$-${RANDOM}"
    PROXY_CONTAINER="hardened-model-proxy-$suffix"
    PROXY_EGRESS_NETWORK="hardened-egress-$suffix"
    PROXY_INTERNAL_NETWORK="hardened-internal-$suffix"
    hardened_resolve_host_identity
    uid="$HARDENED_HOST_UID"
    gid="$HARDENED_HOST_GID"

    PROXY_CLIENT_TOKEN="$(hardened_random_hex 32)"
    PROXY_CLIENT_FILE="$(mktemp "${TMPDIR:-/tmp}/hardened-proxy-client.XXXXXXXX")"
    printf '%s\n' "$PROXY_CLIENT_TOKEN" > "$PROXY_CLIENT_FILE"
    chmod 600 "$PROXY_CLIENT_FILE"
    export PROXY_CLIENT_TOKEN

    docker network create --driver bridge --label agents.proxy=1 "$PROXY_EGRESS_NETWORK" >/dev/null
    if ! docker network create --driver bridge --internal --label agents.proxy=1 \
        -o com.docker.network.bridge.gateway_mode_ipv4=isolated "$PROXY_INTERNAL_NETWORK" >/dev/null 2>&1; then
        hardened_die "locked mode needs Docker isolated gateway mode, which this engine lacks; upgrade Docker or run this audit on a host that supports it"
    fi

    # The sidecar alone holds the reusable provider credential. The agent gets
    # only an ephemeral, per-run client token accepted by this one sidecar.
    docker run -d \
        --label agents.proxy=1 \
        --name "$PROXY_CONTAINER" \
        --platform "$PLATFORM" \
        --label hardened.component=model-credential-proxy \
        --network "$PROXY_EGRESS_NETWORK" \
        --network-alias model-api \
        --user "$uid:$gid" \
        --init \
        --read-only \
        --cap-drop=ALL \
        --security-opt=no-new-privileges:true \
        --pids-limit 64 \
        --memory 256m \
        --cpus 0.5 \
        --tmpfs "/tmp:rw,nosuid,nodev,size=32m,uid=$uid,gid=$gid" \
        --tmpfs "/run:rw,nosuid,nodev,size=16m,uid=$uid,gid=$gid" \
        --mount "type=bind,src=$secret_file,dst=/run/secrets/provider_credential,readonly" \
        --mount "type=bind,src=$PROXY_CLIENT_FILE,dst=/run/secrets/client_credential,readonly" \
        -e "PROXY_MODE=$mode" \
        -e "PROXY_MAX_REQUESTS=$max_requests" \
        "$proxy_image" >/dev/null

    if [[ "$allow_agent_egress" == 1 ]]; then
        AGENT_NETWORK="$PROXY_EGRESS_NETWORK"
        AGENT_NETWORK_DOCKER_ARGS=(--network "$AGENT_NETWORK")
    else
        docker network connect --alias model-api "$PROXY_INTERNAL_NETWORK" "$PROXY_CONTAINER"
        AGENT_NETWORK="$PROXY_INTERNAL_NETWORK"
        PROXY_INTERNAL_IP="$(docker inspect --format "{{(index .NetworkSettings.Networks \"$PROXY_INTERNAL_NETWORK\").IPAddress}}" "$PROXY_CONTAINER")"
        [[ "$PROXY_INTERNAL_IP" =~ ^[0-9]+([.][0-9]+){3}$ ]] || hardened_die "could not determine the proxy internal IP"
        # Disable Docker's external DNS forwarding. model-api resolves through
        # /etc/hosts, so the agent needs no DNS service in restricted mode.
        AGENT_NETWORK_DOCKER_ARGS=(
            --network "$AGENT_NETWORK"
            --dns 192.0.2.53
            --add-host "model-api:$PROXY_INTERNAL_IP"
        )
    fi
    export AGENT_NETWORK PROXY_INTERNAL_IP

    local attempt
    for ((attempt = 0; attempt < 40; attempt++)); do
        if docker exec "$PROXY_CONTAINER" node -e \
            'fetch("http://127.0.0.1:8080/healthz").then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))' \
            >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.25
    done

    docker inspect --format 'credential proxy state={{.State.Status}} exit={{.State.ExitCode}} error={{.State.Error}}' "$PROXY_CONTAINER" >&2 || true
    docker logs "$PROXY_CONTAINER" >&2 || true
    hardened_die "credential proxy did not become healthy"
}





hardened_cleanup_proxy() {
    if [[ -n "$GITHUB_PUSH_CONTAINER" ]]; then
        docker rm -f "$GITHUB_PUSH_CONTAINER" >/dev/null 2>&1 || true
    fi
    if [[ -n "$GITHUB_PUSH_NETWORK" ]]; then
        docker network rm "$GITHUB_PUSH_NETWORK" >/dev/null 2>&1 || true
    fi
    if [[ -n "$PROXY_CONTAINER" ]]; then
        docker rm -f "$PROXY_CONTAINER" >/dev/null 2>&1 || true
    fi
    if [[ -n "$PROXY_INTERNAL_NETWORK" ]]; then
        docker network rm "$PROXY_INTERNAL_NETWORK" >/dev/null 2>&1 || true
    fi
    if [[ -n "$PROXY_EGRESS_NETWORK" ]]; then
        docker network rm "$PROXY_EGRESS_NETWORK" >/dev/null 2>&1 || true
    fi
    if [[ -n "$DIRECT_AGENT_NETWORK" ]]; then
        docker network rm "$DIRECT_AGENT_NETWORK" >/dev/null 2>&1 || true
    fi
    if [[ -n "$PROXY_CLIENT_FILE" ]]; then
        rm -f -- "$PROXY_CLIENT_FILE" >/dev/null 2>&1 || true
    fi
    PROXY_CLIENT_TOKEN=''
    PROXY_CLIENT_FILE=''
    GITHUB_PUSH_CONTAINER=''
    GITHUB_PUSH_NETWORK=''
    GITHUB_PUSH_QUEUE=''
    GITHUB_PUSH_REPO_URL=''
    GITHUB_PUSH_BRANCH=''
    DIRECT_AGENT_NETWORK=''
    AGENT_NETWORK=''
    export PROXY_CLIENT_TOKEN GITHUB_PUSH_QUEUE GITHUB_PUSH_REPO_URL GITHUB_PUSH_BRANCH AGENT_NETWORK
}

hardened_print_command() {
    local arg
    printf '  '
    for arg in "$@"; do
        printf '%q ' "$arg"
    done
    printf '\n'
}
