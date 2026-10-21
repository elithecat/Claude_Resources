# Security model

Threats this package defends against: repository code and prompt-injected
agents stealing model logins (proxy sidecar with per-session budget; Codex
credential shielded by its sandbox), touching your originals (review copies,
scratch clones), escaping to the host (no host git ever runs against
agent-controlled .git; workspace inspection happens in disposable locked
containers), persisting across projects (hash-keyed caches and sessions;
locked sessions mount no caches; remembered Claude state is transcripts only),
and destroying work (nothing is ever auto-deleted; scratch clones, review
copies, and remembered chats are removed only by your typed confirmation).

Locked (untrusted) sessions never write back to your files. A locked run
copies the target into scratch/ and keeps it; there is no accept step, so
hostile code cannot reach the review-and-accept path or its symlink handling.
The accept path runs only for trusted local sessions, where the files and any
symlinks are your own. This is structural: review reads only pending/, which
locked sessions never populate.

Agent sandboxes and the container boundary: Docker is the isolation boundary,
not the agents' own sandboxes. Codex runs with --dangerously-bypass-approvals-and-sandbox and
no permission profile, because profile mode makes it nest a bubblewrap sandbox
that cannot start in an unprivileged, cap-dropped container. Claude runs with its bash sandbox
disabled: bubblewrap must create a user namespace, which this cap-dropped
container blocks, and even Anthropic's enableWeakerNestedSandbox compatibility
mode (which solves the /proc mount) still requires that namespace. Claude's
filesystem and network deny lists in managed-locked.json are therefore NOT
enforced by Claude; locked mode's protection is the container itself plus the
absence of credentials and of any network beyond the model provider. The container keeps cap-drop=ALL,
no-new-privileges, read-only root, and a non-root user in every mode; nothing is
run privileged and CAP_SYS_ADMIN is never added.

Consequence for trusted Codex sessions: with full access, commands Codex runs
can read anything the container can, including the mounted ChatGPT credential
at /home/agent/.codex/auth.json and the GitHub token at /gh. Previously the
permission profile hid those from spawned commands; that protection is gone
because it depended on a sandbox that cannot run here. This is consistent with
trusted mode's stated posture (your own repositories, your own credentials), and
it is why untrusted code belongs in --locked, which mounts no ChatGPT auth (it
uses the API-key proxy instead), no GitHub token, and no Stata license, and has
no network beyond the model provider. If you want trusted Codex without exposing
the subscription credential, authenticate with ./authenticate-codex.sh api-key
so trusted sessions use the proxy too.

Accepted risks, by explicit user decision: default sessions on your own
repositories mount the GitHub token and Stata license read-only with open
network. Use --locked for code you do not trust. Shrink the blast radius by
logging gh in with a fine-grained personal access token scoped to only the
repositories agents should touch.

Locked-mode networking uses Docker internal networks plus a dead DNS server;
on Linux hosts a container can still address the bridge gateway, so services
bound on all interfaces there are reachable. On macOS with Docker Desktop the
gateway terminates in the VM and host-name resolution is dead, materially
blunting this. True host isolation needs firewall rules and is on the
roadmap. Review compares file contents, names, symlinks, and executability;
it does not compare full permission bits (accept does not propagate them) and
refuses copies containing nested git repositories unless forced.

Locked networking requires Docker's isolated gateway mode and refuses to
launch a locked session on an engine that lacks it, rather than degrading
silently. Locked
Codex sessions use the credential proxy with an API key and never see the
ChatGPT auth file. Stale credential sidecars from crashed runs are garbage
collected at the next launch. Per-project caches persist by design within a
project; reset one with rm -rf state/cache/<project>.

Known residual limits: the request budget caps call count, not tokens or
dollars; the Codex egress budget counts tunnels, not API calls;
review does not represent empty directories; the workspace is a bind mount, so the
initial copy is size-checked (MAX_WORKSPACE_MB, default 4096) but a running
agent can still fill the host disk by writing into /workspace; there is no
in-session hard quota because a bind mount cannot carry one, and enforcing it
would require mounting each workspace on a per-session loopback or
quota-backed volume instead. This is a denial-of-service limit, not a
credential or escape risk; language package installs from
CRAN, PyPI, and npm are not hash-locked; scratch auto-deletion trusts git
output produced inside a locked container. No mode auto-deletes anything.
