# Claude Code Docker setup

This folder, the "setup folder," contains scripts that run Claude Code inside a Docker container on your computer. The container has R, Python, Stata, and LaTeX, with common packages for quantitative research. The same scripts can also run Codex, the coding agent from OpenAI.

**Audience:** researchers who write code in R, Python, or Stata. You can type commands in the Terminal, and Docker may be new to you.

**Other documents in the setup folder:**

- [QUICKSTART.md](QUICKSTART.md): the commands alone, for readers who already use Docker.
- [SECURITY.md](SECURITY.md): the full security model and its known weaknesses.

For more background on Docker, see Alyssa Bilinski's earlier guide: <https://github.com/abilinski/claude-code-docker-setup>.

## Contents

1. [Overview](#overview)
2. [Docker and local installations](#docker-and-local-installations)
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
17. [Files in the setup folder](#files-in-the-setup-folder)

## Overview

Claude Code is an AI coding agent that reads, writes, and runs code. In this guide, "agents" means Claude Code and Codex. Docker runs programs in a "container," a separate Linux system inside your computer. Docker creates each container from an "image," a saved template of a Linux system and its programs. In this setup, Claude Code runs in a container and works on one project at a time.

Work in this setup has 4 steps:

1. You start a session with `./go`, and you name a project: a folder on your computer or a GitHub repository.
2. `./go` copies the folder into a "review copy," or clones the repository, inside the setup folder.
3. Claude works on the review copy or the clone inside the container.
4. After the session, you review the changes and decide what to keep.

This setup has 2 modes: the "default mode" for normal sessions, and "audit mode" for code that you do not trust (see [Audit mode](#audit-mode)).

## Docker and local installations

If you install Claude Code on your computer, Claude Code runs as your user account. A command that you approve has the same access to your files as your user account.

In this setup, Claude Code runs in a container. The container has a copy of one project folder. In the default mode, the container also has your GitHub login and your Stata license. Figure 1 shows the parts of a session in the default mode.

Figure 1. Parts of a session in the default mode. The outer box is your computer, and the inner box is the Docker container. The top arrow shows that the copy of your project is the folder `/workspace` in the container, with read and write access. The middle arrow shows that the container has read-only access to your GitHub login and Stata license. The bottom arrow shows Claude's requests to the proxy container, which contains your Claude login and passes the requests to Anthropic.

```
YOUR COMPUTER
+------------------------------------------------------------------+
|                                                                  |
|  Your other files              Docker container                  |
|  (Documents, Desktop,          +------------------------------+  |
|  email, passwords):            | Claude Code, R, Python,      |  |
|  not in the container          | Stata, LaTeX                 |  |
|                                |                              |  |
|  Copy of one project  ------>  | /workspace (read and write)  |  |
|                                |                              |  |
|  GitHub login and     ------>  | read only                    |  |
|  Stata license                 +------------------------------+  |
|                                               |                  |
|  Proxy container  <---------------------------+                  |
|  (contains your Claude login)                                    |
+------------------------------------------------------------------+
```

Table 1. Access by type of installation. Each cell shows whether Claude Code has access to the item in that type of installation, and how. Audit mode is the mode for code that you do not trust. For example, the first row shows that Claude Code has access to the other files on your computer only in a local installation.

| Item | Local installation | This setup, default mode | This setup, audit mode |
|---|---|---|---|
| Other files on your computer | Yes | No | No |
| Your project folder | The original folder | A copy | A copy |
| Internet | Yes | Yes | Only the model provider (Anthropic for Claude, OpenAI for Codex) |
| GitHub login | Yes, if your computer has one | Yes, read only | No |
| Stata license | Yes | Yes, read only | No |
| Your Claude login | Yes | No (the login is in the proxy container) | No (the login is in the proxy container) |

Other protections in this setup:

- The container runs as a normal user without administrator rights, and its system files are read only.
- Each session has a temporary password for the proxy container, a "session token." The session token works only up to a set number of requests (see [Request limit](#request-limit)).

In the default mode, every program in the session has read access to your GitHub login and Stata license. For this reason, log in with a separate GitHub account that has nothing personal in it.

## Requirements

- **Computer:** a Mac or a Linux computer. The scripts run on macOS and Linux.
- **Docker Desktop:** download it from <https://www.docker.com/products/docker-desktop/>. On Linux, Docker Engine also works.
- **Programs on your computer:** `./setup.sh`, `./go`, and `./review` need Node.js, Python 3.11 or later, git, and rsync.
  - macOS includes rsync.
  - On a Mac, run `xcode-select --install` to install git.
  - Install Node.js from <https://nodejs.org/>.
  - Install Python from <https://www.python.org/downloads/>. To check your version, run `python3 --version`.
- **Claude account:** a Claude subscription, or an Anthropic API key, which Anthropic bills by use.
- **GitHub account:** you need one to work on GitHub repositories. Use a separate account that has nothing personal in it.
- **Stata license file (`stata.lic`):** sessions in the default mode do not start without one. Audit mode does not need one.
- **Codex account (optional):** a ChatGPT subscription for the default mode, and an OpenAI API key for audit mode.
- **Time and disk space:** the first build downloads and compiles many packages. The first build takes a long time and needs space for a large Docker image.

## One-time setup

### Step 1. Docker Desktop

Install Docker Desktop from <https://www.docker.com/products/docker-desktop/>. Open Docker Desktop. Leave Docker Desktop open while you use this setup.

### Step 2. Folder download

On the [Claude_Resources page](https://github.com/elithecat/Claude_Resources), select **Code**. Then select **Download ZIP**. Unzip the file. Move the folder `claude-code-docker-setup` to a permanent place, for example your `Documents` folder.

If you use git, you can clone the repository instead:

```bash
git clone https://github.com/elithecat/Claude_Resources.git
```

Keep your projects outside the setup folder. `./go` stops with an error for a project inside the setup folder.

### Step 3. Terminal

Open the Terminal. Go to the setup folder:

```bash
cd ~/Documents/claude-code-docker-setup
```

If you cloned the repository, the setup folder is `Claude_Resources/claude-code-docker-setup`. Run every command in this guide from the setup folder.

### Step 4. Docker images

```bash
./setup.sh
```

**Steps of `./setup.sh`:**

- The script creates `config.env`, the settings file, from `config.env.example` (see [Settings](#settings)).
- The script creates 5 private folders:
  - `auth/` for logins and the Stata license
  - `state/` for package caches and saved conversations
  - `pending/` for review copies of local folders
  - `scratch/` for clones of GitHub repositories and for copies in audit mode
  - `worktrees/` for temporary clones, which `./go` then moves to `scratch/`
- The script runs quick checks of the scripts on your computer. These checks need Node.js and Python 3.11 or later.
- The script builds 2 Docker images. The image `agents-research` contains Claude Code, Codex, R, Python, Stata, and LaTeX. The image `agents-research-proxy` is for the proxy container.

The first build takes a long time, because R packages compile from source. Later builds are faster, because Docker rebuilds only the parts that changed.

If the Terminal prints `permission denied`, run `bash setup.sh`. The setup script makes the other scripts executable.

### Step 5. Claude login

```bash
./authenticate-claude.sh setup-token
```

**Login steps:**

1. The script runs the Claude command `claude setup-token` in a container with no other logins.
2. The command prints a link. Open the link in your browser.
3. Log in to your Claude account. Approve access.
4. The command prints a login token. Copy the login token.
5. When the command ends, paste the login token at the prompt. The prompt does not display what you paste.
6. The script saves the login token in `auth/secrets/`. Only your user account has read access to the saved token.

The login token is valid for one year. You need a Claude subscription to get one.

To check the login, run `./authenticate-claude.sh status`. To use an Anthropic API key instead, run `./authenticate-claude.sh api-key`. Anthropic bills API use separately from a subscription.

### Step 6. GitHub login

```bash
./authenticate-github.sh login
```

**Login steps:**

1. The script runs the GitHub command-line tool, `gh`, in a container.
2. The tool prints a one-time code and a link. Open the link in your browser.
3. Log in to GitHub with your separate account. Enter the code. Approve access.
4. The script saves the login in `auth/gh/`.

Every session in the default mode has read access to this login. To check the login, run `./authenticate-github.sh status`.

### Step 7. Stata license

```bash
./copy-stata-license.sh
```

This command copies `/Applications/Stata/stata.lic` to `auth/STATA.LIC`. If your license file is in another place, give its path:

```bash
./copy-stata-license.sh /path/to/stata.lic
```

If you have a Stata serial number but no license file, run `./setup-stata-license.sh`. That script runs the Stata activation program inside the container. If activation needs the internet, add `--allow-network`.

### Step 8 (optional). Codex login

```bash
./authenticate-codex.sh chatgpt
```

Use this command to log in to Codex with a ChatGPT subscription. Codex prints a link and a one-time code. Codex sessions in the default mode need this login. Codex sessions in audit mode need an OpenAI API key instead. To save the key, run `./authenticate-codex.sh api-key`.

### Step 9. Setup test

```bash
./tests/agent-smoke.sh
```

The test starts each agent in audit mode on a small test folder. Each agent must list the files in that folder. For Claude Code, the output must include `PASS`. For Codex, the output shows `SKIP` unless you saved an OpenAI API key. After the test, `scratch/` has a copy of the test folder for each agent that the test started. To delete these copies, run `./clean`.

After setup, the setup folder contains these items:

```
claude-code-docker-setup/
├── auth/          your logins and the Stata license (private)
├── state/         package caches and saved conversations
├── pending/       review copies of local folders
├── scratch/       clones of GitHub repositories, and copies in audit mode
├── worktrees/     temporary clones (moved to scratch/)
├── config.env     your settings
├── go             starts a session
├── review         commands to list, see, accept, or reject review copies
└── other scripts and files (see "Files in the setup folder")
```

## Local folders

```bash
./go claude ~/Documents/repos/MyProject
```

Figure 2. A session on a local folder. The arrows show the order of the steps, from left to right. `./go` copies your folder into a review copy in `pending/`, and Claude works on the review copy during the session. Your folder changes only when you accept the review copy with `./review`.

```
Your folder                  Review copy                      Your folder
~/Documents/repos/      -->  pending/MyProject-<date-time> -->  changes only if
MyProject                    (Claude works here)              you accept the
(no change during the                                         review copy
session)
```

1. `./go` copies your folder into `pending/`, in a new folder that has the date and time in its name. `./go` also records a checksum of every file, a value computed from the contents of the file (a SHA-256 hash). With these checksums, `./review` counts the changed files and detects later changes to your folder. The largest folder that `./go` copies is 4,096 MB (`MAX_WORKSPACE_MB` in [Settings](#settings)).
2. Claude works on the review copy. Your folder does not change.
3. To end the session, type `/exit`.
4. List the review copies:

   ```bash
   ./review
   ```

   Each entry shows the name of the review copy, the original folder, and the numbers of new, removed, and modified files.

5. See every change in a review copy:

   ```bash
   ./review MyProject-<date-time> diff
   ```

6. Keep the changes:

   ```bash
   ./review MyProject-<date-time> accept
   ```

   Type `yes` to confirm. Your folder then has the same files as the review copy. If Claude deleted a file in the review copy, `accept` also deletes that file from your folder. `accept` does not copy git commits from the review copy. If your folder is a git repository, commit the changes yourself. At the end, if every file in your folder matches the review copy, `accept` deletes the review copy.

7. To discard the changes, delete the review copy:

   ```bash
   ./review MyProject-<date-time> reject
   ```

   Type `yes` to confirm. Your folder does not change.

**Checks during accept:**

- If your folder changed after `./go` made the review copy, `accept` stops. With `--force`, `accept` overwrites those changes in your folder. Copy the changed files that you want to keep to another folder. Then run `./review MyProject-<date-time> accept --force`.
- If a session still runs on the review copy, `accept` stops.
- If the review copy contains another git repository, such as a git submodule, `accept` stops. `./review MyProject-<date-time> diff` does not show the changes inside that repository. Inspect that repository yourself before you use `--force`.
- After `accept` writes the review copy into your folder, `accept` compares every file in your folder with the review copy. If any file differs, `accept` does not delete the review copy, so that you can inspect it.

To accept every review copy, oldest first, run `./review accept-all`. Type `yes` to confirm. If 2 review copies come from the same folder, `accept-all` accepts the older copy first. If the older copy has changes, `accept-all` does not accept the newer copy, and the newer copy stays in `pending/`.

## GitHub repositories

```bash
./go claude https://github.com/you/Repo "Create and switch to a branch named session/2026-10-21-tables. Make the tables. Push the branch."
```

Figure 3. A session on a GitHub repository. The arrows show the order of the steps, from left to right. `./go` clones the repository into `scratch/`, and Claude works and commits in that clone. Claude then pushes a new branch to GitHub for you to review and merge. Your own clone of the repository, if you have one, does not have the work until you pull the branch from GitHub.

```
GitHub repository  -->  scratch/Repo-<date-time>  -->  GitHub
                        (Claude works and commits      (a new branch for
                        here, then pushes)             you to review and merge)
```

1. `./go` clones the repository into `scratch/` with your GitHub login. The GitHub address must start with `https://github.com/`.
2. Claude works in the clone. Claude can commit and push with your GitHub login.
3. When the session ends, `./go` deletes the clone if GitHub has all the work from the clone. If the clone has uncommitted changes or commits that are not on GitHub, `./go` prints the reason and does not delete the clone.
4. Review the branch on GitHub. To keep the work, merge the branch with a pull request.

To keep the clone also when GitHub has all its work, add `--keep` after `./go`. To delete every folder in `scratch/`, run `./clean`. Type `yes` to confirm. `./clean` also deletes clones with work that is not on GitHub. To delete one folder, add its name: `./clean <name>`.

To start from a specific branch, add its name after the task:

```bash
./go claude https://github.com/you/Repo "task" my-branch
```

**Branches.** Run each session on its own branch. Put this text at the start of each task: "Create and switch to a branch named session/<date>-<topic>. Commit as you go. Push the branch before finishing. Never push main."

If a push fails because the branch changed on GitHub, do not force the push. End the session. Start a new session. `./go` clones the current version of the repository. Repeat the task in the new session.

## Conversations and one-task runs

In the commands below, `<project>` is a folder path or a GitHub address.

- **Conversation:** `./go claude <project>` opens Claude with an empty prompt. Type your requests.
- **Conversation with a first task:** `./go claude <project> "task"` sends the task first. You can then continue the conversation.
- **One-task run:** `./go --once claude <project> "task"` runs the task and exits without stopping for input. A one-task run needs a task.

**No permission prompts.** In both modes, Claude edits files and runs commands without asking first. Claude works on a copy or a clone inside the container. Files in your project folders change only when you accept a review copy. In the default mode, Claude can also push to GitHub with your GitHub login.

Give specific instructions. Review every change before you accept a review copy or merge a branch.

**Model.** You choose the model for Claude sessions with `CLAUDE_MODEL` in `config.env` (`opus` in the example file). To switch models during a session, type `/model`.

**Instructions.** Claude Code receives notes about the container from `AGENTS.md` in the setup folder (`AGENTS-locked.md` in audit mode). In this setup, Claude Code does not load the project's `CLAUDE.md` files, because `./go` starts Claude Code with `--setting-sources user`. Sessions in this setup also do not have your `~/.claude/CLAUDE.md`, and Claude Code does not use the project's `.claude/settings.json`. To give Claude the rules in the project's `CLAUDE.md`, start each task with "Read CLAUDE.md and follow its rules."

**Connectors and web search.** Connectors and MCP (Model Context Protocol) servers connect Claude to outside services, such as Gmail. In this setup, both are off. Web search is on in the default mode.

**Saved conversations.** By default, a conversation ends with its session, and you cannot resume it later. To keep a conversation, start the session with `--remember`:

```bash
./go --remember claude ~/Documents/repos/MyProject
```

To continue the conversation later, start a new session with `--remember` on the same project. Then type `/resume`. Before you give Claude a new request, check `git log`, because the files may differ from what the conversation describes.

## Several sessions at once

Each `./go` starts its own container. Run each session in its own Terminal window.

- Each session on a local folder has its own review copy.
- Each session on a GitHub repository has its own clone. Give each session its own branch.
- If you use `-p` in several sessions, give each session a different number (see [Web apps and notebooks](#web-apps-and-notebooks)).
- Each session has its own request limit.

## Session management

- **End a session:** type `/exit` in Claude Code.
- **List running sessions:** run `./ps`.
- **Open a shell (a command line) in a running session:** run `./enter-running.sh`. If more than one session runs, add the container name from `./ps`, for example `./enter-running.sh <container>`.
- **Stop a session from outside:** run `docker stop <container>`.
- **See the output of a one-task run while it runs:** run `docker logs <container>`.
- **Open a shell without an agent:** run `./shell.sh <folder>`. This shell works on your original folder, and `./shell.sh` makes no review copy. The options `--allow-network`, `--with-stata`, and `--github-creds` add internet access, Stata, and your GitHub login. Each of these options requires `--trusted`. Run `./shell.sh --help` for details.

## Web apps and notebooks

A "port" is the number after the colon in an address such as `localhost:3000`. When a session "publishes" a port, Docker connects that port on your computer to a port in the container. By default, a session publishes no ports, and your browser cannot connect to a web app inside the container. To view an app, add `-p 0`:

```bash
./go -p 0 claude ~/Documents/repos/MyApp
```

- With `-p 0`, Docker connects ports 3000, 5173, 8080, and 8888 on your computer to the same ports in the container.
- With `-p 1`, Docker connects ports 3001, 5174, 8081, and 8889 on your computer to ports 3000, 5173, 8080, and 8888 in the container. With `-p 2`, the ports on your computer are 3002, 5175, 8082, and 8890, and so on.
- Only programs on your own computer have access to these ports.

Inside the container, the app must listen on IP address `0.0.0.0` and on port 3000, 5173, 8080, or 8888. Use port 8888 for Jupyter.

For a Shiny app, ask Claude to start the app with `shiny::runApp(port = 3000, host = "0.0.0.0")`. Then open <http://localhost:3000>. The image does not include the shiny package, and Claude can install it during the session.

## Audit mode

Use audit mode for code that you do not trust, such as a repository from a stranger:

```bash
./go --locked claude https://github.com/them/TheirRepo "Audit this code. Describe what it does and what it accesses. Write the findings to AUDIT.md."
```

In audit mode:

- The session has no GitHub login and no Stata license.
- The session can connect only to the model provider.
- Claude cannot use web search, web pages, or MCP servers.
- `./go` copies the folder, or clones the repository, into `scratch/`. Your files do not change, and audit mode has no accept step.
- Audit mode with Codex needs an OpenAI API key.

Read the findings in the new folder in `scratch/`. `./go` prints the path of this folder. To delete only this folder, run `./clean <name>` with its name. `./clean` without a name deletes every folder in `scratch/`.

## Settings

`./setup.sh` creates `config.env` from `config.env.example`. Edit `config.env` in a text editor. Most changes apply to the next session. Changes to the versions or to `STATA_EDITION` apply after you rebuild the images with `./setup.sh`. To change the versions, you can also use `./update.sh` (see [Updates](#updates)).

Table 2. Main settings in `config.env`. The middle column gives the value in `config.env.example`. "Conversation session" means a session without `--once`. For example, `MEMORY_LIMIT=16g` limits each session to 16 GB of memory.

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

### Request limit

Each session can send a limited number of requests to the model provider. Each tool call and each file read counts as a request. When a session reaches its request limit, Claude shows this error:

```
429 per-run provider request limit reached
```

Your files are safe, because all of Claude's work is already in `pending/` or `scratch/`. To continue the session, run this command in another Terminal window:

```bash
./bump-proxy-limit.sh 50000
```

Type `yes` to confirm. Each Claude session has its own proxy container. If more than one proxy container runs, the command stops and changes nothing.

Claude reconnects on its next attempt. To raise the request limit for later sessions, change `PROXY_MAX_REQUESTS_INTERACTIVE` (conversation sessions) or `PROXY_MAX_REQUESTS_AUTONOMOUS` (one-task runs) in `config.env`.

## Updates

To install newer versions of Codex and Claude Code, run:

```bash
./update.sh <codex-version> <claude-version>
```

The script writes the new versions in `config.env` and rebuilds the images. To update only Claude Code, leave the first version empty: `./update.sh "" <claude-version>`.

## Installed software

Table 3. Software in the container, by category. The `Dockerfile` lists exact versions of Python, Stata, and Node.js. For example, the first row shows that the container has Python 3.12.

| Category | Software |
|---|---|
| Languages | Python 3.12, R, Stata 19 (SE edition), Node.js 24, Ruby |
| Python packages | numpy, pandas, matplotlib, seaborn, scipy, statsmodels, scikit-learn, requests, jupyter, jupyterlab, jupytext, papermill, ipywidgets, nbstata (Stata in Jupyter) |
| R packages for data | tidyverse, data.table, haven, readxl, openxlsx, janitor, lubridate, here, fs, jsonlite, glue, httr2 |
| R packages for econometrics | fixest, did, lfe, estimatr, sandwich, clubSandwich, plm, AER, ivreg, rdrobust, DRDID, gsynth, Synth, synthdid (from GitHub; absent if that installation fails) |
| R packages for models | lme4, survival, caret, randomForest, MASS, Matrix, broom, car |
| R packages for tables and reports | modelsummary, stargazer, kableExtra, knitr, rmarkdown, tinytex |
| R packages for graphs | patchwork, cowplot, ggrepel, ggthemes, viridis, scales, gridExtra |
| Other R packages | parallel, foreach, doParallel, future, devtools, Rcpp, sf, terra, IRkernel (R in Jupyter) |
| Documents | LaTeX (with XeLaTeX and latexmk), pandoc, Jekyll |
| Tools | git, GitHub command-line tool (`gh`), ripgrep, jq, Claude Code, Codex |

During a session, Claude installs packages into a cache for the project, in `state/cache/`. Claude can use these packages in later sessions on the same project. Sessions in audit mode have no package cache. To add a package to the image for every project, edit `Dockerfile` or `requirements-python.txt`. Then run `./setup.sh`.

## Troubleshooting

Table 4. Common messages, their causes, and fixes. The message column shows the part of each message that the Terminal prints. `<copy>` is the name of a review copy, as `./review` lists it. For example, if the Terminal prints `permission denied`, run `bash setup.sh` once.

| Message | Cause | Fix |
|---|---|---|
| `permission denied` | The script is not executable | Run `bash setup.sh` once |
| `node: command not found` | Node.js is not on your computer | Install Node.js (see [Requirements](#requirements)) |
| `No module named 'tomllib'` | Your Python version is older than 3.11 | Install Python 3.11 or later (see [Requirements](#requirements)) |
| `Cannot connect to the Docker daemon` | Docker Desktop is not open | Open Docker Desktop |
| `Stata license is not configured` | `auth/STATA.LIC` is missing | Run `./copy-stata-license.sh` (Step 7) |
| `no Claude credential` | `auth/` contains no Claude login | Run `./authenticate-claude.sh setup-token` (Step 5) |
| `GitHub authentication is missing` | `auth/` contains no GitHub login | Run `./authenticate-github.sh login` (Step 6) |
| `no Codex login` | `auth/` contains no Codex login | Run `./authenticate-codex.sh chatgpt` (Step 8) |
| `429 per-run provider request limit reached` | The session reached its request limit | Run `./bump-proxy-limit.sh 50000` (see [Request limit](#request-limit)) |
| `over the 4096 MiB limit` | The folder is larger than the size limit in `MAX_WORKSPACE_MB` | Raise `MAX_WORKSPACE_MB`, or move large files out of the folder |
| `refusing to run on the agents package directory` | The project is inside the setup folder | Move the project out of the setup folder |
| `port is already allocated` | Another session already publishes that port | Use a different `-p` number, or stop the other session |
| `The original changed after this copy was made` | Your folder changed after `./go` made the review copy | `accept --force` overwrites those changes. Copy the changed files that you want to keep to another folder. Then run `./review <copy> accept --force` |
| `the copy contains nested git repositories` | The review copy contains another git repository, such as a git submodule | Inspect that repository yourself. Then run `./review <copy> accept --force` |
| `an agent session is still running on this copy` | A session still runs on the review copy | End the session. Then run `./review <copy> accept` |

**Cleanup:**

- `./review <copy> reject` deletes a review copy.
- `rm -rf pending/*` deletes every review copy without a review.
- `./clean` deletes every folder in `scratch/` after you type `yes`. To delete one folder, run `./clean <name>`.
- `rm -rf state/sessions` deletes every saved conversation.
- `rm -rf state/cache/<cache>` deletes the package cache of one project. To see the cache names, run `ls state/cache`.
- `./authenticate-claude.sh logout`, `./authenticate-github.sh logout`, and `./authenticate-codex.sh logout` delete the saved logins.

## Quick reference

Table 5. Commands for common tasks. Run each command from the setup folder. `<project>` is a folder path or a GitHub address. `<copy>` is the name of a review copy, and `<name>` is the name of a folder in `scratch/`. For example, to start a conversation on a local folder, run `./go claude ~/path/to/folder`.

| Task | Command |
|---|---|
| Build the images (once) | `./setup.sh` |
| Log in to Claude | `./authenticate-claude.sh setup-token` |
| Log in to GitHub | `./authenticate-github.sh login` |
| Add the Stata license | `./copy-stata-license.sh` |
| Test the setup | `./tests/agent-smoke.sh` |
| Work on a local folder | `./go claude ~/path/to/folder` |
| Work on a GitHub repository | `./go claude https://github.com/user/repo "task"` |
| Run a single task without a conversation | `./go --once claude <project> "task"` |
| Keep the conversation for `/resume` | `./go --remember claude <project>` |
| View a web app | `./go -p 0 claude <project>` |
| Audit code that you do not trust | `./go --locked claude <project> "task"` |
| List review copies | `./review` |
| See the changes in a review copy | `./review <copy> diff` |
| Accept a review copy | `./review <copy> accept` |
| Reject a review copy | `./review <copy> reject` |
| List running sessions | `./ps` |
| Open a shell in a running session | `./enter-running.sh` |
| Delete one folder in `scratch/` | `./clean <name>` |
| Reset or raise the request limit | `./bump-proxy-limit.sh 50000` |
| Update Claude Code and Codex | `./update.sh <codex-version> <claude-version>` |

## Files in the setup folder

Table 6. Files in the setup folder and their purposes. For example, `go` is the script that starts a session.

| File | Purpose |
|---|---|
| `README.md` | This guide |
| `QUICKSTART.md` | The commands alone |
| `SECURITY.md` | Security model and known weaknesses |
| `setup.sh` | Builds the images |
| `go` | Starts a session |
| `review` | Commands to list, see, accept, or reject review copies |
| `clean` | Deletes folders in `scratch/` |
| `ps` | Lists running sessions |
| `enter-running.sh` | Opens a shell in a running session |
| `shell.sh` | Opens a shell in a new container, without an agent |
| `authenticate-claude.sh`, `authenticate-github.sh`, `authenticate-codex.sh` | Save logins |
| `copy-stata-license.sh`, `setup-stata-license.sh` | Save the Stata license |
| `bump-proxy-limit.sh` | Resets or raises the request limit of a running session |
| `update.sh` | Changes the versions of Claude Code and Codex, then rebuilds the images |
| `config.env.example` | Default settings |
| `Dockerfile`, `requirements-python.txt` | Contents of the images |
| `AGENTS.md`, `AGENTS-locked.md` | Notes for the agents about the container, in the default mode and in audit mode |
| `managed-default.json`, `managed-locked.json` | Claude Code settings for the default mode and for audit mode |
| `credential-proxy.mjs`, `codex-egress-proxy.mjs` | Programs in the proxy container |
| `clone-private.sh`, `github-helper.sh`, `stata-license-helper.sh`, `container-entrypoint.sh`, `codex-system-config.toml`, `python-stack-smoke.py` | Helper files for the other scripts |
| `lib/common.sh` | Shared functions for the scripts |
| `tests/` | Checks of the scripts and of a finished setup |
