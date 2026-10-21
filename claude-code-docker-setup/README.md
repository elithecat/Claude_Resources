# Claude Code Docker setup

This folder contains scripts that run Claude Code inside a Docker container on your computer. The container has R, Python, Stata, and LaTeX, with common packages for quantitative research. The same scripts can also run Codex, the coding agent from OpenAI.

**Who this guide is for:** researchers who write code in R, Python, or Stata. You can type commands in the Terminal, and Docker may be new to you.

**Other documents in this folder:**

- [QUICKSTART.md](QUICKSTART.md): the commands alone, for readers who already use Docker.
- [SECURITY.md](SECURITY.md): the full security model and its known limits.

For more background on Docker, see Alyssa Bilinski's earlier guide: <https://github.com/abilinski/claude-code-docker-setup>.

## Contents

1. [Overview](#overview)
2. [Docker and local installs](#docker-and-local-installs)
3. [Requirements](#requirements)
4. [One-time setup](#one-time-setup)
5. [Local folders](#local-folders)
6. [GitHub repositories](#github-repositories)
7. [Conversations and one-task runs](#conversations-and-one-task-runs)
8. [Several sessions at once](#several-sessions-at-once)
9. [Session management](#session-management)
10. [Web apps and notebooks](#web-apps-and-notebooks)
11. [Audit mode](#audit-mode)
12. [Settings](#settings)
13. [Updates](#updates)
14. [Installed software](#installed-software)
15. [Troubleshooting](#troubleshooting)
16. [Quick reference](#quick-reference)
17. [Files in this folder](#files-in-this-folder)

## Overview

Claude Code is an AI assistant that reads, writes, and runs code. Docker runs programs in a "container," a separate Linux system inside your computer. In this setup, Claude Code runs in a container and works on 1 project at a time.

Each session has 4 steps:

1. You start a session with `./go`, and you name a project: a folder on your computer or a GitHub repository.
2. `./go` copies the folder, or clones the repository, into this setup folder.
3. Claude works on that copy inside the container.
4. You review the changes and decide what to keep.

## Docker and local installs

If you install Claude Code on your computer, it runs as your user account. A command that you approve can read and change every file that your account can reach.

In this setup, Claude Code runs in a container. The container has a copy of 1 project folder, plus the logins that this setup gives it. Figure 1 shows the parts of a session in the default mode.

Figure 1. Parts of a session in the default mode. Arrows show what goes into the container. The proxy container passes Claude's requests to Anthropic and contains your Claude login.

```
YOUR COMPUTER
+------------------------------------------------------------------+
|                                                                  |
|  Your other files              Docker container                  |
|  (Documents, Desktop,          +------------------------------+  |
|  email, passwords):            | Claude Code, R, Python,      |  |
|  not in the container          | Stata, LaTeX                 |  |
|                                |                              |  |
|  Copy of 1 project  -------->  | /workspace (read and write)  |  |
|                                |                              |  |
|  GitHub login and   -------->  | read only                    |  |
|  Stata license                 +------------------------------+  |
|                                               |                  |
|  Proxy container  <---------------------------+                  |
|  (contains your Claude login)                                    |
+------------------------------------------------------------------+
```

Table 1. Access by type of installation. "Default mode" is a normal session in this setup. "Audit mode" is for code that you do not trust (see [Audit mode](#audit-mode)). Each cell answers this question: can Claude Code reach the item in that setting?

| Item | Local install | This setup, default mode | This setup, audit mode |
|---|---|---|---|
| Other files on your computer | Yes | No | No |
| Your project folder | The original folder | A copy | A copy |
| Internet | Yes | Yes | Only the model provider |
| GitHub login | Yes, if your computer has one | Yes, read only | No |
| Stata license | Yes | Yes, read only | No |
| Your Claude login | Yes | No (the proxy container keeps it) | No (the proxy container keeps it) |

Other protections in this setup:

- The container runs as a normal user without administrator rights, and its system files are read only.
- The session gets a temporary token that works only through the proxy container, up to a set number of requests (see [Request budget](#request-budget)).
- In the default mode, every program in the session can read your GitHub login and Stata license. For this reason, log in with the separate GitHub account from the workshop.

## Requirements

- **Computer:** a Mac or a Linux computer. The scripts are written for macOS and Linux.
- **Docker Desktop:** download it from <https://www.docker.com/products/docker-desktop/>. On Linux, Docker Engine also works.
- **git, Python 3, and rsync:** the review commands use them on your computer. macOS includes rsync. On a Mac, run `xcode-select --install` to install git and Python 3.
- **Claude login:** a Claude subscription, or an Anthropic API key.
- **GitHub account:** you need one to work on GitHub repositories. Use the separate account from the workshop.
- **Stata license file (`stata.lic`):** default sessions do not start without one. Audit mode does not need one.
- **Codex login (optional):** a ChatGPT subscription or an OpenAI API key.
- **Time and disk space:** the first build downloads and compiles many packages. It takes a long time and needs space for a large Docker image.

## One-time setup

### Step 1. Install Docker Desktop

Install Docker Desktop from <https://www.docker.com/products/docker-desktop/>. Open Docker Desktop. Leave it running while you use this setup.

### Step 2. Download this folder

On the [Claude_Resources page](https://github.com/elithecat/Claude_Resources), select **Code**, then **Download ZIP**. Unzip the file. Move the folder `claude-code-docker-setup` to a permanent place, for example your `Documents` folder.

If you use git, you can clone the repository instead:

```bash
git clone https://github.com/elithecat/Claude_Resources.git
```

Keep your projects outside this folder. `./go` stops with an error for a project inside it.

### Step 3. Open the folder in the Terminal

```bash
cd ~/Documents/claude-code-docker-setup
```

Run every command in this guide from this folder.

### Step 4. Build the images

```bash
./setup.sh
```

**What this command does:**

- It creates `config.env`, the settings file, from `config.env.example` (see [Settings](#settings)).
- It creates private folders: `auth/` for logins and the Stata license, `state/` for package caches and saved chats, `pending/` for review copies, and `scratch/` and `worktrees/` for clones.
- It runs quick checks of the scripts.
- It builds 2 Docker images. The image `agents-research` contains Claude Code, Codex, R, Python, Stata, and LaTeX. The image `agents-research-proxy` is for the proxy container.

The first build takes a long time, because R packages compile from source. Later builds are faster, because Docker reuses the parts that did not change.

If the Terminal shows `permission denied`, run `bash setup.sh`. The setup script makes the other scripts executable.

### Step 5. Log in to Claude

```bash
./authenticate-claude.sh setup-token
```

**What happens:**

1. The script runs the Claude command `claude setup-token` in a container with no other logins.
2. The command prints a link. Open the link in your browser.
3. Sign in to your Claude account. Approve access.
4. The command prints a token. Copy the token.
5. When the command ends, paste the token at the prompt. The prompt does not display what you paste.
6. The script saves the token in `auth/secrets/`. Only your user account can read it.

The token lasts 1 year, and it requires a Claude subscription. To check the login, run `./authenticate-claude.sh status`. To use an Anthropic API key instead, run `./authenticate-claude.sh api-key`. API use is billed separately from a subscription.

### Step 6. Log in to GitHub

```bash
./authenticate-github.sh login
```

**What happens:**

1. The script runs the GitHub command-line tool, `gh`, in a container.
2. The tool prints a one-time code and a web address. Open the address in your browser.
3. Enter the code. Approve access for your GitHub account.
4. The script saves the login in `auth/gh/`.

Log in with the separate GitHub account from the workshop. Every default session can read this login. To check the login, run `./authenticate-github.sh status`.

### Step 7. Add your Stata license

```bash
./copy-stata-license.sh
```

This command copies `/Applications/Stata/stata.lic` to `auth/STATA.LIC`. If your license file is in another place, give its path:

```bash
./copy-stata-license.sh /path/to/stata.lic
```

If you have a Stata serial number but no license file, run `./setup-stata-license.sh`. That script runs the Stata activation program inside the container. If activation needs the internet, add `--allow-network`.

### Step 8 (optional). Log in to Codex

```bash
./authenticate-codex.sh chatgpt
```

This command signs in with a ChatGPT subscription. Codex prints a link and a one-time code. To use an OpenAI API key instead, run `./authenticate-codex.sh api-key`.

### Step 9. Test the setup

```bash
./tests/agent-smoke.sh
```

The test starts each agent in audit mode on a small test folder. Each agent must list the files in that folder. For Claude, the output must include `PASS`. For Codex, the output shows `SKIP` unless you stored an OpenAI API key.

After setup, the folder contains these items:

```
claude-code-docker-setup/
├── auth/          your logins and the Stata license (private)
├── state/         package caches and saved chats
├── pending/       review copies of local folders
├── scratch/       clones of GitHub repositories
├── worktrees/     clones during download
├── config.env     your settings
├── go             starts a session
├── review         lists, shows, accepts, or rejects review copies
└── other scripts and files (see "Files in this folder")
```

## Local folders

```bash
./go claude ~/Documents/repos/MyProject
```

Figure 2. A session on a local folder. Changes reach your folder only when you accept them.

```
Your folder                  Review copy                      Your folder
~/Documents/repos/      -->  pending/MyProject-<date-time> -->  changes only if
MyProject                    (Claude works here)              you accept them
(no change during the
session)
```

1. `./go` copies your folder into `pending/`, in a new folder that has the date and time in its name. `./go` also records a fingerprint (a SHA-256 hash) of every file.
2. Claude works on the copy. Your folder does not change.
3. To end the session, type `/exit`.
4. List the review copies:

   ```bash
   ./review
   ```

   Each entry shows the original folder and the numbers of new, removed, and modified files.

5. See every change in 1 copy:

   ```bash
   ./review MyProject-<date-time> diff
   ```

6. Keep the changes:

   ```bash
   ./review MyProject-<date-time> accept
   ```

   Type `yes` to confirm. Your folder then matches the copy exactly, including files that Claude deleted.

7. Or delete the copy and keep your folder as it is:

   ```bash
   ./review MyProject-<date-time> reject
   ```

**Checks during accept:**

- If your folder changed after `./go` made the copy, `accept` stops. Look at the changes, then run `./review MyProject-<date-time> accept --force`.
- If a session still runs on the copy, `accept` stops.
- After the copy step, `accept` compares every file in your folder with the copy. If any file differs, `accept` keeps the copy for you to inspect.

`./review accept-all` accepts every review copy, oldest first. The largest folder that `./go` copies is 4,096 MB (`MAX_WORKSPACE_MB` in [Settings](#settings)).

## GitHub repositories

```bash
./go claude https://github.com/you/Repo "Create and switch to a branch named session/2026-10-21-tables. Make the tables. Push the branch."
```

Figure 3. A session on a GitHub repository. Your computer has no copy of the work until you pull it from GitHub.

```
GitHub repository  -->  scratch/Repo-<date-time>  -->  GitHub
                        (Claude works and commits      (a new branch for
                        here, then pushes)             you to review and merge)
```

1. `./go` clones the repository into `scratch/` with your GitHub login. `./go` accepts only addresses that start with `https://github.com/`.
2. Claude works in the clone. Claude can commit and push with your GitHub login.
3. When the session ends, `./go` deletes the clone if all its work is on GitHub. If the clone has uncommitted changes or commits that were not pushed, `./go` keeps the clone and prints the reason.
4. Review the branch on GitHub. To keep the work, merge the branch with a pull request.

To keep every clone, add `--keep` after `./go`. To delete kept clones, run `./clean`, then type `yes` to confirm.

To start from a specific branch, add its name after the task:

```bash
./go claude https://github.com/you/Repo "task" my-branch
```

**Branches.** Run each session on its own branch. Start each task with this text, or put the text in the repository's `CLAUDE.md`: "Create and switch to a branch named session/<date>-<topic>. Commit as you go. Push the branch before finishing. Never push main."

If GitHub rejects a push because the branch changed on GitHub, do not force the push. End the session. Start a new session, which clones the current version, and repeat the task.

## Conversations and one-task runs

In the commands below, `<project>` is a folder path or a GitHub address.

- **Conversation:** `./go claude <project>` opens Claude with an empty prompt. Type your requests.
- **Conversation with a first task:** `./go claude <project> "task"` sends the task first. You can then continue the conversation.
- **One-task run:** `./go --once claude <project> "task"` runs the task and exits without stopping for input. A one-task run needs a task.

**No permission prompts.** In every mode, Claude edits files and runs commands without asking first. Claude works on a copy inside the container, and changes reach your files only when you accept them. Give specific instructions, and review every change before you accept it.

**Model.** `config.env` sets the model for Claude sessions (`CLAUDE_MODEL=opus`). To switch models during a session, type `/model`.

**Instructions.** Claude reads the project's `CLAUDE.md` as usual. Claude also receives the notes in `AGENTS.md` from this setup folder, which describe the container. Claude does not use the project's `.claude/settings.json`. MCP servers and connectors are off. Web search is on in the default mode.

**Saved chats.** By default, a chat ends with its session, and `/resume` cannot find it later. To keep a chat, start the session with `--remember`:

```bash
./go --remember claude ~/Documents/repos/MyProject
```

To continue the chat later, start again with `--remember` on the same project, and type `/resume`. Check `git log` first, because the files may differ from what the chat describes.

## Several sessions at once

Each `./go` starts its own container. Run each session in its own Terminal window.

- Each session on a local folder gets its own review copy.
- Each session on a GitHub repository gets its own clone. Give each session its own branch.
- If sessions publish ports, give each session a different `-p` number (see [Web apps and notebooks](#web-apps-and-notebooks)).
- Each session has its own request budget.

## Session management

- **End a session:** type `/exit` in Claude Code.
- **List running sessions:** run `./ps`.
- **Open a shell in a running session:** run `./enter-running.sh`. If more than 1 session runs, add the container name from `./ps`, for example `./enter-running.sh <name>`.
- **Stop a session from outside:** run `docker stop <name>`.
- **See the output of a one-task run while it runs:** run `docker logs <name>`.
- **Open a shell without Claude:** run `./shell.sh <folder>`. This shell works on your folder directly, not on a copy. Options such as `--trusted --allow-network --with-stata --github-creds` add internet access, Stata, and your GitHub login. Run `./shell.sh --help` for details.

## Web apps and notebooks

By default, a session publishes no ports, and your browser cannot reach a web app inside the container. To view an app, add `-p 0`:

```bash
./go -p 0 claude ~/Documents/repos/MyApp
```

- `-p 0` connects ports 3000, 5173, 8080, and 8888 on your computer to the same ports in the container.
- `-p 1` uses ports 3001, 5174, 8081, and 8889 on your computer, and so on.
- Only your own computer can open these ports.

Inside the container, the app must listen on address `0.0.0.0` and on port 3000, 5173, 8080, or 8888. For a Shiny app, ask Claude to start the app with `shiny::runApp(port = 3000, host = "0.0.0.0")`. Then open <http://localhost:3000>. The image does not include the shiny package, and Claude can install it during the session. Use port 8888 for Jupyter.

## Audit mode

Use audit mode for code that you do not trust, such as a repository from a stranger:

```bash
./go --locked claude https://github.com/them/TheirRepo "Audit this code. Describe what it does and what it accesses. Write the findings to AUDIT.md."
```

In audit mode:

- The session has no GitHub login and no Stata license.
- The session can reach only the model provider.
- Claude cannot use web search, web pages, or MCP servers.
- `./go` copies the folder, or clones the repository, into `scratch/`. Nothing is written to your files, and audit mode has no accept step.

Read the findings in `scratch/`, then delete the copy with `./clean`. Audit mode with Codex needs an OpenAI API key.

## Settings

`./setup.sh` creates `config.env` from `config.env.example`. Edit `config.env` in a text editor. Most changes apply to the next session. Version changes apply after you rebuild the images (see [Updates](#updates)).

Table 2. Main settings in `config.env`. The middle column gives the value in `config.env.example`. "Conversation session" means a session without `--once`.

| Setting | Value in the example file | Meaning |
|---|---|---|
| `CLAUDE_MODEL` | `opus` | Model for Claude sessions; an empty value means the default model of your account |
| `MEMORY_LIMIT` | `16g` | Maximum memory for each session (16 GB) |
| `CPU_LIMIT` | `4` | Maximum number of CPUs for each session |
| `PROXY_MAX_REQUESTS_INTERACTIVE` | `50000` | Maximum number of model requests in each conversation session |
| `PROXY_MAX_REQUESTS_AUTONOMOUS` | `50000` | Maximum number of model requests in each one-task run |
| `MAX_WORKSPACE_MB` | `4096` | Size of the largest local folder that `./go` copies, in MB |
| `GIT_USER_NAME` and `GIT_USER_EMAIL` | `Research Agent` and `research-agent@users.noreply.github.com` | Name and email on commits from sessions |
| `CLAUDE_VERSION` and `CODEX_VERSION` | `2.1.281` and `0.156.1` | Versions of Claude Code and Codex in the image |
| `STATA_EDITION` | `se` | Stata edition in the image |

### Request budget

Each session can send a limited number of requests to the model provider. Each tool call and each file read counts as a request. When a session reaches the limit, Claude shows this error:

```
429 per-run provider request limit reached
```

Your files are safe, because everything that the agent wrote is already in `pending/` or `scratch/`. To continue the session, run this command in another Terminal window:

```bash
./bump-proxy-limit.sh 50000
```

The agent reconnects on its next attempt. To raise the limit for later sessions, change `PROXY_MAX_REQUESTS_INTERACTIVE` in `config.env`.

## Updates

To install newer versions of Codex and Claude Code, run:

```bash
./update.sh <codex-version> <claude-version>
```

The script writes the new versions in `config.env` and rebuilds the images. To update only Claude Code, leave the first version empty: `./update.sh "" <claude-version>`.

## Installed software

Table 3. Software in the container, by category. The versions of Python, Stata, and Node.js are fixed in the `Dockerfile`.

| Category | Software |
|---|---|
| Languages | Python 3.12, R, Stata 19 (SE edition), Node.js 24, Ruby |
| Python packages | numpy, pandas, matplotlib, seaborn, scipy, statsmodels, scikit-learn, requests, jupyter, jupyterlab, jupytext, papermill, ipywidgets, nbstata (Stata in Jupyter) |
| R packages for data | tidyverse, data.table, haven, readxl, openxlsx, janitor, lubridate, here, fs, jsonlite, glue, httr2 |
| R packages for econometrics | fixest, did, lfe, estimatr, sandwich, clubSandwich, plm, AER, ivreg, rdrobust, DRDID, gsynth, Synth, synthdid (installed from GitHub when that step succeeds) |
| R packages for models | lme4, survival, caret, randomForest, MASS, Matrix, broom, car |
| R packages for tables and reports | modelsummary, stargazer, kableExtra, knitr, rmarkdown, tinytex |
| R packages for graphs | patchwork, cowplot, ggrepel, ggthemes, viridis, scales, gridExtra |
| Other R packages | parallel, foreach, doParallel, future, devtools, Rcpp, sf, terra, IRkernel (R in Jupyter) |
| Documents | LaTeX (with XeLaTeX and latexmk), pandoc, Jekyll |
| Tools | git, GitHub command-line tool (`gh`), ripgrep, jq, Claude Code, Codex |

Packages that Claude installs during a session go into a cache for that project, in `state/cache/`. Later sessions on the same project can use them. Audit mode does not use the cache. To add a package to the image for every project, edit `Dockerfile` or `requirements-python.txt`, then run `./setup.sh`.

## Troubleshooting

Table 4. Common messages, their causes, and fixes. The message column shows the part of each message that the Terminal prints.

| Message | Cause | Fix |
|---|---|---|
| `permission denied` | The script is not marked as executable | Run `bash setup.sh` once |
| `Cannot connect to the Docker daemon` | Docker Desktop is not running | Open Docker Desktop |
| `Stata license is not configured` | `auth/STATA.LIC` is missing | Run `./copy-stata-license.sh` (Step 7) |
| `no Claude credential` | No Claude login is stored | Run `./authenticate-claude.sh setup-token` (Step 5) |
| `GitHub authentication is missing` | No GitHub login is stored | Run `./authenticate-github.sh login` (Step 6) |
| `no Codex login` | No Codex login is stored | Run `./authenticate-codex.sh chatgpt` (Step 8) |
| `429 per-run provider request limit reached` | The session used its request budget | Run `./bump-proxy-limit.sh 50000` (see [Request budget](#request-budget)) |
| `over the 4096 MiB limit` | The folder is larger than the copy limit | Raise `MAX_WORKSPACE_MB`, or move large files out of the folder |
| `refusing to run on the agents package directory` | The project is inside this setup folder | Move the project out of this folder |
| `port is already allocated` | Another session uses that port | Use a different `-p` number, or stop the other session |
| `The original changed after this copy was made` | Your folder changed during the session | Check the diff, then run `./review <copy> accept --force` |
| `an agent session is still running on this copy` | The session on the copy has not ended | End the session, then accept |

**Cleanup:**

- `./review <copy> reject` deletes 1 review copy.
- `rm -rf pending/*` deletes every review copy without a review.
- `./clean` deletes kept clones in `scratch/` after you type `yes`.
- `rm -rf state/sessions` deletes every saved chat.
- `rm -rf state/cache/<project>` deletes the package cache of 1 project.
- `./authenticate-claude.sh logout`, `./authenticate-github.sh logout`, and `./authenticate-codex.sh logout` delete the stored logins.

## Quick reference

Table 5. Commands for common tasks. Run each command from the `claude-code-docker-setup` folder.

| Task | Command |
|---|---|
| Build the images (once) | `./setup.sh` |
| Log in to Claude | `./authenticate-claude.sh setup-token` |
| Log in to GitHub | `./authenticate-github.sh login` |
| Add the Stata license | `./copy-stata-license.sh` |
| Test the setup | `./tests/agent-smoke.sh` |
| Work on a local folder | `./go claude ~/path/to/folder` |
| Work on a GitHub repository | `./go claude https://github.com/user/repo "task"` |
| Run 1 task without a conversation | `./go --once claude <project> "task"` |
| Keep the chat for `/resume` | `./go --remember claude <project>` |
| View a web app | `./go -p 0 claude <project>` |
| Audit code that you do not trust | `./go --locked claude <project> "task"` |
| List review copies | `./review` |
| See the changes in a copy | `./review <copy> diff` |
| Accept a copy | `./review <copy> accept` |
| Reject a copy | `./review <copy> reject` |
| List running sessions | `./ps` |
| Open a shell in a running session | `./enter-running.sh` |
| Delete kept clones | `./clean` |
| Reset or raise the request budget | `./bump-proxy-limit.sh 50000` |
| Update Claude Code and Codex | `./update.sh <codex-version> <claude-version>` |

## Files in this folder

Table 6. Files in this folder and their purposes.

| File | Purpose |
|---|---|
| `README.md` | This guide |
| `QUICKSTART.md` | The commands alone |
| `SECURITY.md` | Security model and known limits |
| `setup.sh` | Builds the images |
| `go` | Starts a session |
| `review` | Lists, shows, accepts, or rejects review copies |
| `clean` | Deletes kept clones in `scratch/` |
| `ps` | Lists running sessions |
| `enter-running.sh` | Opens a shell in a running session |
| `shell.sh` | Opens a shell in the image without an agent |
| `authenticate-claude.sh`, `authenticate-github.sh`, `authenticate-codex.sh` | Store logins |
| `copy-stata-license.sh`, `setup-stata-license.sh` | Store the Stata license |
| `bump-proxy-limit.sh` | Resets or raises the request budget of a running session |
| `update.sh` | Changes the versions of Claude Code and Codex, then rebuilds |
| `config.env.example` | Default settings |
| `Dockerfile`, `requirements-python.txt` | Contents of the images |
| `AGENTS.md`, `AGENTS-locked.md` | Notes for the agent about the container, in the default mode and in audit mode |
| `managed-default.json`, `managed-locked.json` | Claude Code settings for the default mode and for audit mode |
| `credential-proxy.mjs`, `codex-egress-proxy.mjs` | Programs in the proxy container |
| `clone-private.sh`, `github-helper.sh`, `stata-license-helper.sh`, `container-entrypoint.sh`, `codex-system-config.toml`, `python-stack-smoke.py` | Helpers that the other scripts use |
| `lib/common.sh` | Functions that the scripts share |
| `tests/` | Checks of the scripts and of a finished setup |
