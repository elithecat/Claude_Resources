# Claude Code Docker setup: quick reference

> New to Docker? See [README.md](README.md) for the step-by-step guide.

One container setup for Codex and Claude Code, built for research work in
Python, R, Stata, and TeX. One command runs either agent with your defaults
baked in: full internet, full git against your GitHub account, Stata mounted,
per-project package caches, repo instructions loaded, and no dialogs.

Your originals are never edited directly. Local folders run on a pending copy
you accept or reject. GitHub URLs run in a scratch clone under `scratch/` that is
yours to delete with `./clean` once its branch is pushed. Model logins sit behind a proxy sidecar with a
per-session budget, so nothing in a session can steal them. Chats are
forgotten at exit unless you ask to remember.

## One-time setup

```bash
cd claude-code-docker-setup
./setup.sh
./authenticate-github.sh login
./authenticate-codex.sh chatgpt
./authenticate-claude.sh setup-token
cp /Applications/Stata/stata.lic auth/STATA.LIC
```

The build reuses the heavy R, Python, TeX, and Stata layers from the v16
images if they exist in your Docker cache, so it is fast.

After building and logging in, run the end-to-end check once. It launches each
agent and has it execute a real shell command, which catches sandbox or
container-compatibility problems that the offline test suites cannot:

```bash
./tests/agent-smoke.sh
```

Both agents should report PASS. If either shows a `bwrap` error, the agent's
inner sandbox is fighting the container; tell me what it printed.

## Daily commands

Run an agent on one of your local project folders (review-copy mode):

```bash
./go claude ~/Documents/repos/MyProject
./go codex ~/Documents/repos/MyProject "Rerun the estimator and fix warnings"
```

The task is optional. Omit it (first line) and the agent opens with an empty
prompt for you to type into, the way you would use it directly. Give one
(second line) and the session starts with that already submitted. `--once`
always needs a task, since it never stops for input.

Then judge the result:

```bash
./review                       # list pending copies with change counts
./review <copy-name> diff      # the full patch of what the agent did
./review <copy-name> accept    # your folder becomes exactly the copy
./review <copy-name> reject    # delete the copy; nothing ever happened
```

Run an agent straight from GitHub (scratch mode; nothing lands on your Mac):

```bash
./go codex https://github.com/you/Repo "Create branch session/runtime-checks, do X, push the branch before finishing"
```

Nothing is ever auto-deleted: the clone stays under `scratch/` with its path
printed, and `./clean` removes leftovers when you say so.

Useful flags, combinable:

```bash
./go --once   codex <target> "task"     # run the task and exit, no prompt after
./clean                                 # list and delete scratch clones (asks first)
./go --remember claude <target> "task"  # keep this chat; /resume finds it later
./go --locked codex <url> "audit task"  # stranger-code mode (codex needs an
                                        # API key stored once); no internet beyond
                                        # the model, no GitHub token, no Stata
./go -p 1     claude <target> "task"    # publish ports 3001/5174/8081/8889
```

## Sessions, memory, resume

By default a session's chat is forgotten at exit. To keep one, decide at
launch:

```bash
./go --remember codex ~/Documents/repos/MyProject "long refactor, day 1"
```

Remembered chats are filed per project under `state/sessions/`. To continue
one, launch with `--remember` on the same target and use `/resume` inside the
agent. Even resumed sessions should start with a glance at `git log`, since
the files may have moved on while the memory stood still.

## Docker operations

```bash
./ps                          # which agent sessions are running right now
./enter-running.sh            # open a bash shell inside the running session
./enter-running.sh <id>       # same, when more than one is running
docker stop <id>              # stop a session from outside
docker logs <id>              # what a --once session printed
./shell.sh --trusted --allow-network --with-stata --github-creds <folder>
                              # a plain research shell, no agent, for hand work
```

`./enter-running.sh` is a side door into a live session: the agent keeps
running in its own terminal while you poke around the same container.

## Multiple sessions on one GitHub repo, best practices

GitHub is the single source of truth; sessions are disposable spokes. The
rules that keep parallel work painless:

1. One branch per session, and nothing pushes `main` directly. Start every
   task with: "Create and switch to a branch named session/<date>-<topic>.
   Commit as you go. Push the branch before finishing. Never push main."
   Put that sentence in the repo's `CLAUDE.md` and `AGENTS.md` once and every
   session obeys it automatically.
2. Parallel sessions never share a writing surface. Every URL launch gets its
   own scratch clone and its own branch, so any number can run at once without
   collisions or rejected pushes. For local work, each `./go` on a folder gets
   its own pending copy, so parallel attempts at the same task are isolated
   too; accept the best one.
3. Merge through review. When a session's branch looks good on GitHub, use
   the pull-request button (or tell any session "merge session/X into main
   and push"). Branches whose work was superseded just get deleted.
4. Keep one long-lived clone per project under `~/Documents/repos/` for your
   own hands and for review-copy sessions. Never let it hold uncommitted work
   when a session starts, and let sessions sync it themselves: begin tasks on
   it with "git fetch origin and rebase onto origin/main first".
5. If a push is ever rejected as non-fast-forward, the remote moved after the
   session started. Don't force. Exit, relaunch (fresh clone = current
   remote), and re-apply; or have the session `git fetch && git rebase
   origin/main && git push`.
6. Nothing is judged by scripts. Accept, reject, and clean are yours, each
   asks first, and accept refuses while that copy's session is still running.
7. Treat agent-touched checkouts as untrusted until judged. Inspect pending
   copies with `./review <name> diff` and kept scratch folders by opening
   files, not by running your own `git` inside them: a hostile session can
   plant executable git configuration, and this package's own tooling always
   invokes git with that configuration disabled. `accept` applies file
   changes only and never transplants a copy's `.git` onto your folder.
8. Work exists when it is pushed; the habit that makes agents safe to
   interrupt.

## How acceptance verifies what lands

When you accept a copy, the tool does not trust git to tell it what changed,
because a repository can use `.gitattributes` (for example the `ident` filter)
to make git's view differ from the real bytes on disk. Instead, at copy time
it records a manifest of the actual bytes: for every file a SHA-256 of its raw
content, for every symlink its exact target, for every directory its presence.
That manifest, not git, decides what the agent changed and whether your
original drifted in the meantime.

On accept it copies with `rsync --checksum` (so a change that happens to
preserve a file's size and timestamp is still applied), then re-manifests the
destination and refuses to finish unless your folder byte-matches the reviewed
copy. If anything fails to land, the copy is kept for inspection rather than
silently declared done. The manifest is generated by an isolated Python
process (`python3 -I`), so a hostile repo cannot smuggle in a `hashlib.py` or
`pathlib.py` to hijack it, and any unreadable file or malformed hash aborts the
whole operation rather than recording a blank. In short: what you see in
`./review diff` is what lands, and nothing lands unverified.

## Audit mode for code you don't trust

```bash
./go --locked codex https://github.com/them/TheirRepo "Audit this code: what does it do, what does it touch, is anything suspicious? Write findings to AUDIT.md"
./go --locked codex ~/Downloads/some-untrusted-repo "Same, on a local folder"
```

Locked sessions have no GitHub credential, no Stata license, and no network
beyond the model provider, so hostile code has nothing to steal and no way to
phone home. They never write back to your files: a URL is cloned into
`scratch/`, and a local folder is copied into `scratch/`, and the agent works
only on that copy. There is no accept step for a locked session, by design, so
untrusted code never reaches the review-and-accept path at all. You read the
agent's findings in the `scratch/` folder, then `./clean`.

If you audit an outside repo, decide it's fine, and want its changes, merge
them the ordinary way: review the git diff yourself and pull the branch,
rather than having an agent apply them.

## If a session hits the request budget

Each run has a provider-request budget (every tool call and file read is a
request, so long sessions add up). Hitting it looks like:

```
429 per-run provider request limit reached
```

Your files are safe: the workspace is a live bind mount, so everything the
agent wrote is already in `pending/` or `scratch/`. Only the chat is lost if
you exit.

To keep the session alive, restart the proxy in place from another terminal:

```bash
./bump-proxy-limit.sh 50000     # or with no number, just resets the counter
```

The agent reconnects on its next retry. To stop it happening again, raise
`PROXY_MAX_REQUESTS_INTERACTIVE` in `config.env` (the default, 1000, is
conservative for interactive research sessions).

## Maintenance

```bash
./update.sh 0.145.0 2.2.0     # bump Codex and/or Claude pins, rebuild, retest
./update.sh 0.145.0           # bump only Codex
./ps                          # nothing running? then safe to clean:
./clean                       # delete scratch clones
rm -rf pending/*              # discard all unjudged review copies
rm -rf state/sessions         # forget all remembered chats
rm -rf state/cache/<project>  # reset one project's R/pip/ado packages
./authenticate-github.sh status   # check credentials; also -codex, -claude
```

## Layout

```
go                     the launcher            auth/       your credentials + STATA.LIC
review, clean, ps      judgment and cleanup    pending/    review copies awaiting you
shell.sh, enter-running.sh                     scratch/    kept clones from URL runs
authenticate-*.sh      one-time logins         state/      caches and remembered chats
setup.sh, update.sh    build and upgrade
```

Everything under `auth/` is yours and survives updates. `pending/`,
`scratch/`, and `state/` are reconstructible; `./clean` and `./review reject`
prune them safely.
