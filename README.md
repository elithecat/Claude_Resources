# Claude Resources

Materials for the workshop "Getting Started with Claude Code" (Brown University, October 21, 2026).

- `CLAUDE_template.md`: a general rules file to copy and adapt.
- `beamer_template/`: Alyssa's beamer slide template, shown with her deck "Using LLMs in research" (September 2026). Compile `llms_2026_research_slides.tex` with XeLaTeX. On Overleaf, set the compiler to XeLaTeX. The theme uses the Libertinus fonts. The script `code/llm_expectation_curve.R` draws the figures.
- Docker: [setup resources to be added].

## What CLAUDE.md does

CLAUDE.md is a plain-text (Markdown) file of instructions. Claude Code reads it at the start of every session. Use it to:

- explain the project: what it is, where files live, and how to run it;
- set rules for one project, for example the build command, the folder layout, or what to commit;
- keep general rules that you want in every project, for example "never make up numbers" or "ask before you delete files."

Write down what you would otherwise explain again in each session. When Claude makes the same mistake twice, add a rule. Keep each file short (Anthropic suggests fewer than about 200 lines), and write rules that you could check: "Run the tests before you commit," instead of "Test your changes."

## Where CLAUDE.md files live

Table 1. Locations of CLAUDE.md files, from the broadest scope to the narrowest. Claude Code reads every file that applies and combines them; it reads the files closest to your working folder last. Files in the folders above the folder where you start Claude load at the start of the session. Files in subfolders load when Claude reads or edits a file in that subfolder. Source: Anthropic, "How Claude remembers your project."

| Scope | Location | Use for | Who gets it |
|---|---|---|---|
| Your rules, every project | `~/.claude/CLAUDE.md` | General rules that you like | Only you, in all projects |
| Project rules | `CLAUDE.md` or `.claude/CLAUDE.md` in the project folder | Project description and project rules | Everyone who uses the repository |
| Your notes on one project | `CLAUDE.local.md` in the project folder (add it to `.gitignore`) | Personal settings for one project | Only you, in that project |
| Subfolder rules | `CLAUDE.md` in a subfolder | Rules for one part of a project | Everyone who uses the repository |

Organizations can also set one policy file for all of their users. Three commands help:

- `/init` writes a starting CLAUDE.md for a project.
- `/memory` opens your CLAUDE.md files so that you can edit them.
- A line such as `@docs/setup.md` in a CLAUDE.md file imports another file.

## How to use the template

1. Copy `CLAUDE_template.md` to `~/.claude/CLAUDE.md` for rules in every project, or to `CLAUDE.md` in a repository for one project.
2. Fill in the items in [brackets].
3. Delete the rules that you do not want, and add your own.

## Getting started with a project

- **Describe the project:** what it is and what it is for.
- **Give context:** the documents that will be useful.
- **Specify the tasks:** what to do, and what "done" looks like.
- **Plan first:** ask for a plan before any changes (plan mode).
- **Give Claude a way to check its work:** tests or expected outputs.

Source: Anthropic, "Best practices for Claude Code," and Alyssa Bilinski.

## Model and thinking level

- Choose the model with `/model`, for example `/model opus`.
- Choose the thinking level with `/effort`, for example `/effort high`. The levels are low, medium, high, xhigh, and max. Opus 5.5 starts at medium.
- Alyssa's choice: at least Opus 5.5 at high effort, sometimes Fable, and never Sonnet.

## Docker

[Docker setup resources to be added.]

## Sources

- Anthropic. How Claude remembers your project. https://code.claude.com/docs/en/memory
- Anthropic. Best practices for Claude Code. https://code.claude.com/docs/en/best-practices
- Anthropic. Model configuration. https://code.claude.com/docs/en/model-config
- Anthropic. Use Claude Code in the cloud. https://code.claude.com/docs/en/claude-code-on-the-web
