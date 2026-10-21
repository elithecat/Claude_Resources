# Claude Resources

Materials for the workshop "Getting Started with Claude Code" (Brown University, October 21, 2026).

- `claude_code_workshop_slides.pdf`: the workshop slides, one page per slide.
- `CLAUDE_template.md`: a general rules file to copy and adapt.
- `beamer_template/`: Alyssa's beamer slide template, shown with her deck "Using LLMs in research" (September 2026).
  - Compile `llms_2026_research_slides.tex` with XeLaTeX, twice. On Overleaf, set the compiler to XeLaTeX.
  - The theme requires the Libertinus fonts. To compile on your own computer, install these fonts first.
  - The script `code/llm_expectation_curve.R` draws the figures with the R packages ggplot2 and data.table. Run the script from the top folder of this repository.
- `claude-code-docker-setup/`: scripts that run Claude Code or Codex in a Docker container, with R, Python, Stata, and LaTeX. See "Docker" below.

## Purpose of CLAUDE.md

CLAUDE.md is a plain-text (Markdown) file of instructions. Claude Code reads it at the start of every session. Use it to:

- explain the project: what it is, where the files are, and how to run it;
- set rules for one project, for example the build command, the folder layout, or what to commit;
- keep general rules that you want in every project, for example "never make up numbers" or "ask before you delete files."

Write down the explanations that you repeat in each session. Update the file as you go. When Claude makes an error, add a rule. Keep each file short. Anthropic suggests fewer than 200 lines per file. Write rules that you can check, for example "Run the tests before you commit," instead of "Test your changes."

## CLAUDE.md locations

Your "working folder" is the folder where you start Claude Code. At the start of a session, Claude Code reads the CLAUDE.md files in your working folder and in the folders above it. Claude Code reads the CLAUDE.md file in a subfolder when Claude reads or edits another file in that subfolder. Claude Code combines all the files that apply, and it reads the files closest to your working folder last.

Table 1. Locations of CLAUDE.md files, from the broadest scope to the narrowest. A "cloud session" is a Claude Code session at claude.ai/code, on a computer that Anthropic manages. For example, the first row shows that the rules in `~/.claude/CLAUDE.md` apply only to you, in every project on your computer. Sources: Anthropic, "How Claude remembers your project" and "Configure cloud environments."

| Scope | Location | Use for | Applies to |
|---|---|---|---|
| Your rules, every project | `~/.claude/CLAUDE.md` on your computer | General rules that you like | Only you, in every project on your computer; cloud sessions do not have this file |
| Project rules | `CLAUDE.md` or `.claude/CLAUDE.md` in the project folder | Project description and project rules | Everyone who uses the repository, also in cloud sessions |
| Your notes on one project | `CLAUDE.local.md` in the project folder (add it to `.gitignore`) | Personal instructions for one project | Only you, in that project on your computer; cloud sessions do not have this file |
| Subfolder rules | `CLAUDE.md` in a subfolder | Rules for one part of a project | Everyone who uses the repository, also in cloud sessions |

Organizations can also set one policy file for all of their users.

You can manage CLAUDE.md files with two commands and one kind of line:

- `/init` writes a starting CLAUDE.md for a project.
- `/memory` opens your CLAUDE.md files so that you can edit them.
- A line such as `@docs/setup.md` in a CLAUDE.md file imports another file.

## Template setup

1. Copy `CLAUDE_template.md` to one of these places:
   - `CLAUDE.md` in a repository, for rules in one project. After you commit and push the file to GitHub, Claude Code also reads it in cloud sessions.
   - `~/.claude/CLAUDE.md` on your computer, for rules in every project on that computer. Cloud sessions do not have this file.
2. Fill in the items in [brackets].
3. Delete the rules that you do not want. The template has 365 lines, and Anthropic suggests fewer than 200 lines per file.
4. Add your own rules.

## New projects

- **Describe the project:** what it is and what it is for.
- **Give context:** the documents that will be useful.
- **Specify the tasks:** what to do and what to deliver.
- **Plan first:** ask for a plan before any changes (plan mode).
- **Give Claude a way to check its work:** tests or expected outputs.

Sources: Anthropic, "Best practices for Claude Code," and Alyssa Bilinski.

## Model and thinking level

- Choose the model with `/model`, for example `/model opus`.
- Choose the thinking level with `/effort`, for example `/effort high`. The levels are low, medium, high, xhigh, and max. The default level for Opus 5.5 is medium.
- Alyssa's choice: at least Opus 5.5 at the high thinking level, sometimes Fable, and never Sonnet.

## Docker

The folder [`claude-code-docker-setup/`](claude-code-docker-setup/) contains scripts that run Claude Code or Codex in a Docker container on your computer. The container has R, Python, Stata, and LaTeX. In this setup, Claude Code does not load CLAUDE.md files. To use the rules in a project's CLAUDE.md, start each task with "Read CLAUDE.md and follow its rules."

- [`README.md`](claude-code-docker-setup/README.md) in that folder is a step-by-step guide: requirements, one-time setup, daily use, and troubleshooting.
- [`QUICKSTART.md`](claude-code-docker-setup/QUICKSTART.md) lists the commands alone.
- [`SECURITY.md`](claude-code-docker-setup/SECURITY.md) describes the security model and its known weaknesses.

## Sources

- Anthropic. How Claude remembers your project. https://code.claude.com/docs/en/memory
- Anthropic. Best practices for Claude Code. https://code.claude.com/docs/en/best-practices
- Anthropic. Model configuration. https://code.claude.com/docs/en/model-config
- Anthropic. Configure cloud environments. https://code.claude.com/docs/en/cloud-environments
