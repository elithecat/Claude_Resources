# CLAUDE.md template for research and analysis projects

This file is a starting set of rules for Claude Code in a research or analysis repository: integrity, how to take instructions, deliverables, writing, figures and tables, analysis and verification, and agent reports.
Use it in one of two ways: copy it into a repository as `CLAUDE.md` for project rules, or install it as `~/.claude/CLAUDE.md` for rules in every project.
Then edit it. Replace every item in [brackets], delete the rules that do not fit your work, and add your own.
An instruction that the user gives in chat takes precedence over this file. A project's own `CLAUDE.md` takes precedence over the user-level file on project matters, such as folder names and build commands.

**Contents.**

1. Working with [your name]
2. Deliverables and documents
3. Writing
4. Figures and tables
5. Analysis, simulation, and verification
6. Agent reports and handoffs
7. Project notes

---

# Part 1. Working with [your name]

## 1.1 Integrity

These rules have no exceptions.

- **Never lie, and never make up data, numbers, or facts.** Never present a partial analysis as complete.
- **Report failures.** If a package does not install, data is missing, or a computation fails, say so plainly and stop. Do the same if a result is interpolated, approximated, or stored instead of computed in the current run.
- **Never substitute fabricated or placeholder values for missing results.** Do not replace real package output with stored numbers, a computed curve with an interpolated curve, or the specified estimator with a different estimator. Make the specified method work, or report what is missing.
- When you cannot complete the work, report exactly what you did and what you did not do.
- **Never invent or change facts** such as counts, citations, journal names, dates, titles, and credentials. Use exactly what the source records. Mark missing facts with `[brackets]` for the user to resolve.
- When the project's instructions say to derive results independently ("do not use published estimates"), do not look up published estimates. Compute the result from data and code, and justify each step.

## 1.2 Following instructions

- **Do what the user says.** When the user gives an explicit instruction, such as an output format, a port, a filename, or a tool, implement the instruction as stated. If you see a real technical problem, mention the problem once and briefly, and still do the work as specified. Do not argue again about settled instructions, and do not treat them as suggestions.
- **Confirm the approach before you start a task**, unless the instruction specifies the approach or tells you to proceed. Before you write code, agree on what "correct" means: the expected outputs, the invariants, and the tests.
- **A question is not approval.** When the user asks a question (for example, "which version of the data did you use?"), answer the question and wait. Do not start the next step.
- **When the user asks you to fix one item, change only that item.** Do not restructure nearby content, retitle nearby sections, or shorten text that the user did not name. Treat each request as an addition unless the request says "replace" or "remove."
- **Treat the user's original content as approved.** Do not delete, merge, re-caption, or "improve" text, figures, slides, or phrasing from the user's own drafts unless asked. Put additions in new places, and keep the originals unchanged.
- **Before you edit inherited material, read its original source** to confirm the purpose of the material.
- **Confirm the location before you edit.** When the user names "slide N" or "page N," render that page of the current output and confirm the content. Then make the edit, render again, and confirm the fix on the same page.
- **Follow the existing convention by default.** When you extend an analysis or a document, keep its rules and structure, and add the new part to them. If you change the convention on purpose, document the change.
- **When you follow a template repository, copy its layout and conventions.** Do not copy its numbers or its errors. Compute every count from the data of the current project.
- **Build tools in small steps.** Start with the simplest version that works on a demonstration input, and then add features. Make each step visible, and explain each script in plain English.

## 1.3 Chat replies

- **Be concise, and avoid unnecessary jargon.** Say what you mean in plain words. Do not add introductory sentences or restatements.
- Quick numbers in prose are acceptable for discussion. Put every result meant for review in a rendered document (Part 2).
- The table rules in Part 4 apply to every table in chat, including short tables.

## 1.4 Language models

- **Use Fable by default** for the main session and for every subagent.
- **If Fable is not available, use the strongest available Opus at its highest reasoning effort.** The minimum is Opus 4.8 at xhigh effort. Do not use a weaker language model or a lower effort.
- **Never use Sonnet or Haiku**: not for the main session, not for subagents, and not for any task.
- **Set the language model explicitly on every subagent.** Never let a subagent run on a default language model.
- If a session starts on a weaker language model or a lower effort, stop. Tell the user to switch with `/model` before you do any work.
- Record the IDs of the language models and the prompt versions wherever results depend on them: supplements, logs, and reports.

## 1.5 Repository scope and git

- **Work only in the repository where the session started.** Do not push commits or files to another repository unless the user names that repository as the target. Treat a link to another repository as material to read, never as a place to write.
- Commit as the repository owner. [State whether a commit may carry a `Co-Authored-By` trailer or any other co-author line.]
- [State the branch policy: commit and push directly to `main`, or work on a branch and open a pull request.] Do not leave deliverables only on another branch. If the host environment cannot push to the chosen branch, push the assigned branch and tell the user its name.
- **Commit after each completed task.** Write a plain, literal commit message. Tell the user which commit to pull.
- **A subagent or an isolated development copy does not commit, merge, or push.** It gives its work to the parent session. The parent session adds the work to the repository after the review in Part 6.
- **Rebuild every affected output before you commit.** Never commit a source change with an out-of-date PDF, Word file, cached data file, figure, or build variant (Part 2.4).
- **Never commit** large or sensitive raw data, API keys, secrets, or private reference material. Add reference copies of other repositories (for example `repos/`) to `.gitignore`. Never push private material to a public repository.
- **Use paths relative to the project root**, with the path tool of the project (in R, `here::i_am()` and `here()`). Never use absolute paths or `setwd()`.

---

# Part 2. Deliverables and documents

## 2.1 Format

- **Deliver every document as a source file rendered to its final format** [for example an `.Rmd` or `.tex` file rendered to PDF]. This rule applies to design documents, reports, write-ups, manuscripts, and verification notes. Render the output even when the user does not ask for it.
- Never deliver only a Markdown file, an unrendered source file, a standalone image, a CSV export, or a Word file. Supporting files can accompany a deliverable, and the complete deliverable must also be in the rendered document.
- **Keep each source file and its rendered output together** in the repository, and commit both.
- **Present results for review in the rendered document**, with the figure or table number. Do not present results as a standalone image, an image in chat, or an unformatted table. To revise, render the document again.
- **Each document must render on its own** from the committed repository. Do not source other scripts from a document. A document can load saved results, but only results that a committed script produces. Name that script in the document.
- **Documents are static.** Put interactive content in an app (for example Shiny or Streamlit), never in a rendered document.
- **When a venue needs Word**, render the manuscript to PDF and `.docx` from the same source with one command (for example `rmarkdown::render(..., output_format = "all")`). PDF is the review format, and Word is the submission format.
- **If a rendering tool is missing** (for example `rmarkdown`, pandoc, or LaTeX), install the tool or report the problem. Do not change the output format without saying so.

## 2.2 Folder layout

Use the layout of the project: [your folder layout]. The numbered layout below is one example.

- `0_Data/`: raw data and derived data. Do not change raw data.
- `1_Code/`: executable code, numbered in run order. Each script sources a shared options file.
- `2_Documents/`: analysis documents (source files rendered to PDF). By default, put every new figure, table, or result for review here.
- `3_Drafts/`: the source files and PDFs of the paper, supplement, slides, or letter, and nothing else.
- `4_Output/`: the figures and tables that the drafts include, written by scripts in `1_Code/`. The drafts reference these files by relative paths. Do not put one-time analysis output here or in `3_Drafts/`, because readers would mistake the output for part of the paper.
- `agent-reports/`: the reports of all agents (Part 6).

Put slow computations in scripts that save their results to `0_Data/`, and the figures and tables for a draft to `4_Output/`. Then the documents load and display only those results, and each document renders in seconds.

## 2.3 Document content

- **Write in plain, concise language.** Use short sentences and short paragraphs. Define every project-specific term at first use.
- If a paragraph contains more than about 3 facts, split the paragraph into a list.
- A collaborator who does not know the code must understand the whole document in one reading.
- **Do not use internal code names in prose** (variable names, script tags, or option codes). Use the English name. Put the correspondence between code names and English names in one cross-reference note near the end.
- **Every design document and report needs figures.** Give every time or window structure a schematic diagram. Give every decision rule with branches a flowchart. A reader must be able to reconstruct the design from the figures and captions alone.
- Write project documentation (for example `architecture.md`) in plain English for an educated college student. Update the documentation when you add a script.

## 2.4 Rendering and checking

- **Before a long run, render the associated documents at small N and read them.** Rendering without errors is not enough. Read the numbers, the rendered formulas, the column headers, and the labels. Look for sign errors, formulas with the wrong index, labels that do not match the text, percentages that are wrong by a factor of 100, and sample sizes that are wrong by the number of arms. Fix each error, render again, and check again.
- **Check that every plot and table fits on the page**: no content past the right margin, no figure that leaves a mostly blank page, no `Overfull \hbox` warning in a LaTeX log, and no label too small to read at the printed size.
- **Rebuild every variant together.** [List the parallel outputs of the project, for example main text and supplement, PDF and Word versions, or slides and print handouts.] After any edit to shared content, rebuild every affected variant before you commit.
- **Use the build command and build folder of the project.** [State the build command here.] Reference figures and tables by relative paths.
- **Regenerate dependent outputs in the same commit.** Before you commit, run the script that creates each cached file again, and render the document again.

## 2.5 Slides

- **Build slides from the template of the project:** [the path to your template]. For beamer slides, one starting point is `beamer_template/` in the Claude Resources repository (<https://github.com/elithecat/claude_resources>). Copy the deck and its `theme/` folder, and compile with XeLaTeX. The theme uses the Libertinus fonts.

---

# Part 3. Writing

These rules apply to all prose: documents, captions, code comments, commit messages, and chat replies.

## 3.1 General

- Write in plain, concise language. Use short sentences, and delete words that add no information.
- Define every technical or project-specific term at first use, and use one term for each concept throughout.
- Never invent facts, numbers, quotations, or citations. Mark a fact that you could not confirm with `[brackets]` for the user to resolve.
- Report failures in the text. Do not describe a result that you did not produce.
- Give every number its unit and its denominator, and give every table and figure a caption that stands on its own (Part 4).
- Use the active voice, and name who did each action.

## 3.2 Mannered prose

Remove all mannered prose. Anthropic defines mannered prose in "Prompting Claude Fable 5.1," section "Writing density" (<https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1#writing-density>):

> Mannered prose substitutes metaphor and flourish for direct statement. Instead of "a parameter worth varying," the mannered writer produces "a dial worth turning." Instead of "this point still matters," they write "this point earns its keep." The phrases exist to display the writer, not to convey the idea, and readers can tell. That is why mannered prose irritates: it makes the reader work harder so the writer can perform. It is also imprecise. Metaphors drag in connotations the writer did not choose and cannot control. The fix is to say what you mean. When a literal phrase is available, use it.

The short form of the rule, for a review prompt, is **"Please remove all mannered prose."**

- **Check density as well as manner.** Every phrase must add information. Sentences with too many clauses, and paragraphs without breaks, are the related problem.
- **Use the literal term.** For every noun and verb, ask whether you use the word in its literal sense for this subject. A parameter is not a dial, a finding cannot earn, and an assumption cannot carry a load. If a word comes from a domain that the subject does not belong to (machinery, architecture, bodies, money, combat, travel, theater), replace the word with the literal term.
- If you cannot think of a literal term, the sentence probably has no clear content. Delete the sentence, or decide what it means. Use a figurative word only when the word is the established technical term and no literal term exists (for example "bootstrap" or "the tail of a distribution").

Common substitutions:

| Mannered | Write instead |
|---|---|
| a dial worth turning, a knob, a lever | a parameter worth varying; a choice |
| earns its keep, pulls its weight, does the heavy lifting | matters; accounts for most of the effect |
| load-bearing, structural (of a claim) | necessary; the result depends on it; central |
| the spine, skeleton, or backbone of the argument | the main claim; the organizing idea |
| anchors, grounds, underpins, scaffolds | supports; is the basis for; justifies |
| unlocks, unpacks, surfaces, sharpens | allows; explains; shows; clarifies |
| navigates, threads the needle, walks a line | handles; balances; chooses between |
| lands, hits home, rings true | is persuasive; is correct; matches the evidence |
| a lens, a frame, through the lens of | a perspective; considered as; in terms of |
| the landscape, the terrain, the space | the field; the set of options; the literature |
| tapestry, mosaic, symphony, dance, journey | the name of the actual system, set, or sequence |
| at the heart of, at its core, at bottom | the main point is; centrally |
| a double-edged sword, a two-way street | has a benefit and a cost (name both) |
| moving parts, plumbing, machinery (of a method) | components; steps; the estimation procedure |
| leans on, rests on, hinges on | uses; depends on; requires |
| honest (of an estimate, a sentence, or a comparison) | unbiased; accurate; direct; correct |
| the bug's footprint, where the 17% lives, craters | the effect of the bug; the source of the 17%; drops sharply |
| the control arm buys back the penalty | a larger control arm removes the penalty |

**Constructions to delete or rewrite:**

- **"Not X but Y" and related forms** ("isn't just X; it's Y," "less a question of X than of Y," "not because X but because Y"). State Y directly. If you need to refute X, refute X in a separate sentence with evidence. A plain correction in the form "write X, not Y" is acceptable.
- **Lists of three for rhythm.** Use three items only when there are three real items. Do not add items to reach three, and do not end a paragraph with a three-part list for effect. More than about 3 such lists per 1,000 words is a common sign of generated text.
- **Closing clauses added for effect** ("and that is the whole point," "which is exactly the problem," "and it shows"). Delete them.
- **Epigrams and quotable sentences at the end of a paragraph** ("Reliable measurement is a precondition for accountability"). Make the point with a number, or delete the sentence.
- **Dramatic fragments** ("A checkbox." "Twice.") and contrasts arranged for effect. Write complete, plain sentences.
- **Colon reveals** ("The answer: …"). Use at most 1 in a document, and never 2 in adjacent paragraphs.
- **Dramatic phrases of zero or one** ("not a single participant"), mock-modest intensifiers ("almost embarrassingly small"), double negatives used for emphasis ("The timing is not incidental"), and empty intensifiers ("actually," "truly," "exactly this").
- **Template phrases**: hedges that cover both sides ("Whatever position one takes…"), concessions before a claim ("This is not a panacea, but…"), closing lists that end with "alike," and comments that describe the argument ("This experience illustrates the underlying problem").
- **Rhetorical questions used as transitions.** State the answer. A list of research questions that states the aims of a paper is acceptable, and so is a question heading that a venue requires.
- **Comments about the text**, beyond a one-sentence outline: "it is worth noting that," "I want to emphasize," "as discussed above," "in what follows," "to put it another way." State each point once, where it belongs. A "Recall that" sentence that restates a definition before you reuse it is acceptable, and so is a roadmap paragraph in a long paper.
- **Repeated qualifiers.** Qualify a claim once, with the specific limit ("in the 12 states with complete data"), and use "may" as the usual modal. Do not stack qualifiers ("arguably," "somewhat," "to some extent," "in many ways," "perhaps"). A true claim without qualifiers is better than a vague claim with many qualifiers. In shorter formats, hedge less: use 1 word per estimate on a web page, and no hedge on a one-pager.
- **Nouns made from verbs, with a weak verb.** Write "evaluate," not "conduct an evaluation of"; "estimate," not "provide an estimation of"; "indicates," not "is indicative of."
- **Evaluative adjectives**: crucial, critical, powerful, elegant, rich, nuanced, compelling, striking, remarkable, profound. State the fact that would make a reader choose the adjective. ("Critical value" as a statistical term is acceptable.)
- **Uniform sentences and paragraph openings.** A series of short thesis sentences at the start of paragraphs ("The fix is small." "The payoff is immediate.") and sentences of the same length are strong signs of generated text. Vary the length of sentences, and vary how paragraphs begin.

**Orwell's six rules** ("Politics and the English Language," 1946):

1. Never use a metaphor, simile, or other figure of speech which you are used to seeing in print.
2. Never use a long word where a short one will do.
3. If it is possible to cut a word out, always cut it out.
4. Never use the passive where you can use the active.
5. Never use a foreign phrase, a scientific word, or a jargon word if you can think of an everyday English equivalent.
6. Break any of these rules sooner than say anything outright barbarous.

**Orwell's questions for each sentence:** What am I trying to say? What words will express it? What image or idiom will make it clearer? Is this image fresh enough to have an effect? Could I put it more shortly? Have I said anything that is avoidably ugly? In research prose, the answer to the third question is almost always "none."

## 3.3 Hidden actors: subject test

An example from an earlier design document: "The reserved band feeds a gate." No person appears in that sentence. A band of years cannot feed a gate, and a gate does not eat. The direct sentence is "We compute the check from the wash-out periods." The same document had windows that "choose" comparison groups, designs that "spend" data, bands that "leak," checks that must "earn their keep," and an experiment that "asks a question." Each of those verbs has an unnamed actor: the analyst.

**For every clause, ask who does the action.** There are three possible answers.

1. **A person** (we, the analyst, researchers, the reader). Make the person the subject. Write "We choose between the two groups with the training window," not "The training window chooses between the two groups."
2. **Nobody, because the clause states a mathematical or logical fact.** An object can be the subject, but only with a relational verb: is, equals, has, contains, implies, depends on, is defined as, follows from, reduces to. Display verbs are also acceptable: "Figure 1 shows," "Table 2 reports," "the header lists." Statements of a mechanism are acceptable: "conditioning introduces a distortion," "autocorrelation couples the period means," "the estimator converges."
3. **Nobody, but the verb implies an actor.** The third answer is the error. The subject is a window, script, pipeline, rule, statistic, scenario, dataset, model, figure, or body of literature, and the verb names an action that a person takes. The sentence has no actor. Rewrite the sentence.

- **Make "we" the subject. Do not replace one object subject with another object subject.** Write "we select Specification 2," not "the rule prefers Specification 2" or "the comparison selects Specification 2." Write "we ran 2,000 replications per scenario," not "each scenario used 2,000 replications." Choosing, selecting, preferring, reading, and using always have a human subject.
- **Banned verbs for non-human subjects:** feeds, decides, wants, tries, asks, tells, knows, sees, watches, judges, chooses, picks, prefers, selects, spends, earns, rescues, guards, polices, resists, survives, leaks, catches, misses, worries, hopes, cares, promises, refuses, insists, warns, suggests, reads, attaches, carries (a message).
- **Verbs to check one at a time:** produces, delivers, drives, motivates, rewards, punishes, protects, underscores, highlights, speaks to. Some of these verbs have a legitimate mechanistic meaning. Check each use with the test above.
- **Name people when you cite.** Write "\citet{roth_pretest_2022} warns," not "the literature warns." Write "researchers worry about X," not "the worry attaches to X." In press writing, name the institution or the design instead of the authors.
- **Draft from the analyst's point of view**: we split the years, we choose a group, we compute a forecast, we report or we abstain. If you describe the pipeline as the actor (data enters, components act on the data, a result comes out), every sentence will have this error.
- **Do not give procedures metaphorical names.** If we call a rule a "gate," we start to write "the band feeds the gate." If we call a check a "judge," we start to write about its verdicts. Use plain names in prose (check, rule, window, band, split). When the code already has a metaphorical name, translate the name once in the cross-reference note, and use the plain name everywhere else. A language-model agent with the role of judge is an actor, and this rule does not apply to it.

## 3.4 Other signs of generated text

- **State results concretely.** Do not write a sentence in which an abstract subject (the pattern, the results, our simulations, the analysis) takes a vague verb (confirms, bears out, reveals, underscores, highlights, speaks to) and a vague generality as its object (the familiar instinct, a practical lesson, the expected trade-off). Write the specific claim. For example, replace "the pattern confirms the familiar instinct to retain data" with "shortening the pre-window lowered power, which is why researchers retain as much pre-intervention data as the design allows."
- If a sentence only says "this matches intuition," delete the sentence.
- **Avoid formulaic parallel sentences.** Do not describe two cases in matched sentences. In such sentences, an abstract subject takes a series of verbs, the second sentence begins its contrast with "instead," and the last clause exists only for effect. State the quantity that distinguishes the cases first, and give each case in one clause: "Whether a shift appears depends on the truncated mean; for the magnitude rules it equals zero, for the signed rules it is nonzero."
- **Do not add subtitles or labels that the source does not have.** A series of short labels under a repeated title is a common sign of generated text.
- **Do not use em dashes** ("—" in Unicode, "---" in LaTeX, or "--" used as an em dash). Use a period, semicolon, colon, parentheses, or comma. En dashes in numeric ranges ("6.5–33.4") are acceptable.

| Do not write | Write instead |
|---|---|
| essentially, basically, fundamentally, simply, merely, actually, really, truly, clearly, obviously, obvious, naturally, of course, in fact, indeed, arguably, effectively, virtually, notably | Delete the word. If a result is approximate, quantify it ("within 1% of the ATT"). |
| just ("just 36%") | Delete the word, or rephrase. |
| thing, things, something, anything, stuff | the category or the specific referent ("three criteria") |
| "we will do two things," "the method does three things" | Name the work. For a real list, number the items and name the category ("we propose two extensions"). |
| simple, straightforward, basic (of an idea or an argument) | Delete the label. "Simple" can describe only a model or an algorithm. |
| delve, robust, leverage, landscape, underscore, operationalize, constituencies, at scale, bespoke, actionable, shippable, evidence generation, immediately doable | a literal word. "Robust" and "leverage" are acceptable as defined statistical terms ("robust standard errors"). |

[Add your own writing style rules here: voice, tense, words to avoid, citation style, and the style reference for each type of document.]

## 3.5 Final passes

Do not call a draft finished until you run each pass and find no errors. Run the passes on the rendered output.

1. **Subjects and verbs.** Read only the subjects and verbs, sentence by sentence, also in captions and diagram text. Find each clause with a non-human subject and a non-relational verb. If the clause states a fact, change the verb to a relational verb. Otherwise, change the subject to the person. Then search for the banned verbs in 3.3.
2. **Figurative language.** For each word, ask whether the word gives its meaning by comparison instead of literally. Search for the left column of the table in 3.2, and for: lens, frame, landscape, navigate, unlock, unpack, anchor, spine, backbone, load-bearing, structural, leverage, journey, tapestry, honest, not just, isn't just, at its core, at the heart.
3. **Banned words and patterns.** Search for every entry in the table in 3.4, and for em dashes.
4. **Tables.** Run the checklist in 4.2 on every table, also on tables in chat.

---

# Part 4. Figures and tables

## 4.1 Figures

- Use [the plotting library of the project, for example ggplot2] and a colorblind-friendly palette. [Name the palette and the figure theme of the project here.]
- **Do not draw gridlines.** Set `panel.grid = element_blank()` for the whole grid. The `theme_bw` default, or blanking only `minor` or `major.x`, leaves lines and is an error. Check every figure after each edit.
- **Use readable facet and axis labels in words**, never raw `TRUE`/`FALSE` values or variable names.
- **Start the y-axis at 0 when the plot shows magnitude.** Never truncate a quantitative axis to make differences look larger.
- Show rates and probabilities as percentages, and put the unit and the denominator in the axis title ("Daily incidence per 100,000 persons").
- Use small multiples with common scales to show differences between groups. When rows show different quantities, free the y-scale and say so in the caption.
- Draw decision thresholds, null values, and policy dates as dashed or dotted reference lines, and say in the caption what each line represents.
- Match the uncertainty display to the model (shaded bands on time series, error bars on discrete estimates, box plots for stochastic simulations), and state the level and the method in the caption.
- Truncate long tails only if the caption says so. Print the value beside each point or inside each cell when readers will read values off the figure.
- **Write self-contained captions**: the axes, the colors and shapes, the population, the dates, the denominator, the method for uncertainty intervals, and all abbreviations. A reader must understand the figure without the main text.
- **Map factor labels explicitly, never by position.** Build every display factor with matched `levels =` and `labels =` arguments. When a grid changes, update its label vectors in the same commit.

## 4.2 Tables

**Every table must be understandable on its own**, in reports, in papers, and in chat. Before you show a table, check these points:

1. **A complete caption comes before the table.** The caption states what the table shows, the source data (design, scenarios, replicates), how you computed each column, and how to read a typical row.
2. **Headers, row labels, and cell contents are descriptive English.** Do not use internal variable names or unexplained compact notation.
3. **Every numeric column has its unit** in the header or in the caption.
4. **Footnotes define every remaining abbreviation and show the arithmetic of derived columns**, so that a reader can check the numbers.
5. **Mark an undefined cell with one symbol per document** ("n.a." or an en dash) and explain it in a note.
6. **Write confidence intervals in one form throughout a document**, and round each column consistently.

In chat, you can omit rows or columns from a shorter table, never the caption, the units, or the descriptive headers. If a full caption is too long for the point, give the numbers in prose instead.

---

# Part 5. Analysis, simulation, and verification

## 5.1 Scope of analyses

- **Do not select a subset.** By default, include the baseline and every estimator, test, comparator, scenario, and parameter grid of the earlier analyses, in every scenario.
- **When you add an independent dimension**, apply the existing selection rule jointly over the old and the new dimensions.
- **Say when two settings give the same procedure.**
- **If you drop a cell** (because of non-convergence or an infeasible sample size), say which cells you dropped and why. Never drop cells without saying so.
- **Select hyperparameters with training data only**, for example with cross-validation inside the training period. Never select with test outcomes. State the tuning rule, and put robustness to alternatives in an appendix.
- [Add the inference conventions of your field here, for example the level at which to cluster standard errors, or the estimator to use under staggered adoption.]
- **Report simulation settings as part of the result**: the number of simulations, the seed, and the Monte Carlo error, for every simulated power, size, or bias. If a setting changes, say so.
- **Use the specified package.** If a required package is not available, stop and tell the user. Do not substitute a different implementation.
- **Keep one file that defines the numbers of options or variants.** Use those numbers in reports, script names, and output files. Update the defining file first.

## 5.2 Evaluating procedures on independent data

- **Implement a nested simulation structure exactly as the protocol specifies it** (for example: for each simulated dataset, run the analysis, compute the critical value of that dataset from an inner bootstrap, and record the decision). Do not substitute a pooled, self-calibrated, or simplified version, even as a documented default.
- **A quantity that is true by construction is never a finding.** Examples are a rejection rate against a threshold tuned on the same draws, and a quantile matched to its own distribution. Do not put such a quantity in a results table.
- **Replace a specified procedure with a faster computation only with a proof of exact equivalence and a test** that compares the two on the same seeds. Where equivalence fails, run the full computation and report its Monte Carlo error.
- **Agreement is not accuracy.** Agreement between agents, or between methods, is a reliability statistic. Accuracy estimates come only from human-labeled samples that are independent of any records used to correct the data.

## 5.3 Testing and verification

- **Every change must be provably correct.** For each new feature (especially a simulation), write a verification document with a description and its mathematical basis, intermediate output (plots and tables at each step), and formal tests.
- **Formal tests include**: equivalence (two estimators with the same assumptions give the same answer), known limits (boundary behavior, large N, steady state), analytical comparison (simulated variance versus the theoretical formula), bias and consistency (Monte Carlo over many runs), and plausibility checks (plausible ranges and expected monotonicity).
- **Agree on the test plan before you write code**: the requirements, the edge cases, the expected outputs, and the invariants.
- **Derive the expected answer of a verification test independently**: by brute force from raw data, with an independent implementation, from a stored reference, or from an algebraic identity. A test that repeats the steps of the implementation shows only that the code agrees with itself. If the implementation is the only source of expected values, say so in the test comment, and call the test a consistency check.
- **When a reviewer, a human check, or an audit finds an error, add a regression test** that fails on the uncorrected code and passes after the correction.
- **Test equivalence-preserving refactors at two levels**: per-function equivalence in the standard test script (the same inputs give the same outputs, to about 1e-9 for floating-point values), and a separate end-to-end script that runs the full pipeline under the old code and the new code and compares the output files.
- **Log intermediate results in readable form**: the parameter values at the start, the actual and expected values, and labeled tables of bias, variance, and MSE. Save logs with a timestamp and the seed to [`output/logs/`].

## 5.4 Optimization and refactoring

- **Profile before you optimize.** Name the slowest function and its share of the run time.
- **Keep the original.** Keep each original function unchanged under an `_orig` name. Give each optimized version a `_fast` suffix, and dispatch to the fast version explicitly.
- **Do not change the scientific content**: the data-generating process, the estimand, the model formula, the time aggregation, the bootstrap algorithm and its number of draws, and the output schema.
- **Match the original exactly** in column names and order, dimensions, classes, attributes, `NA` positions, row order, warnings and errors on fallback cases, and the random-number state after a run with a fixed seed. Match numeric values to the tolerance in the test script of the project.
- **Confirm that the reference output is not degenerate** (all `NA` or constant) before you claim equivalence. If the original is broken, equivalence to the original is not evidence that the fast version is correct.
- **Do not vectorize a loop if vectorization changes the random-number stream.**
- **Outside the tested inputs, do not reproduce errors of the original.** Fall back to the original when the original handles an input correctly, and stop with an error when the original gives a wrong result.
- **Cover the input range in the equivalence script**: random sizes, edge cases (zeros, a single unit, minimal length, rows with all `NA`), and the production parameters. Print PASS or FAIL for each function, and exit with a non-zero status on any failure.
- **Benchmark in a standard way.** Run the original and the fast version one after the other, each in a new process, at least 3 times. Report the median, minimum, and maximum time, the peak memory, and the problem size.
- **Respect the resource limits of the project.** [State them here, for example the maximum number of workers, the memory limit, and no full-scale runs during development.] Never raise the limits to compensate.
- **Check again after every update to the original code**, and mark earlier claims of speed and equivalence as superseded when they no longer apply.
- **An independent reviewer runs the equivalence test again** before anyone uses a fast function in a production script.

## 5.5 Data handling and provenance

- **Do not change raw data.** Store downloads in dated folders with the query strings, the API URL and version, the retrieval time, and SHA-256 checksums. Write derived data to separate folders.
- **Record the snapshot date, the file list, and the row counts** for every external data source. Name downloaded data files `<source_name>_<YYYYMMDD>.<ext>`.
- **Save the cohort or sample when you define it** (commit the list of IDs), and use that list in every later stage. A new download must not change the sample without notice.
- **Use one row for each stable ID in master tables.** Resolve one-to-many relations before a join, and test the row counts after every join. Use stable IDs, never row numbers.
- **Log the count after every filter step.** The counts must match the flow diagram exactly.
- **Validate the data before you make displays**: schemas, allowed values, missing values, unique IDs, parsed dates, denominators, and totals.
- **Record exact dependency versions and seeds** (`set.seed`, `renv`, or `requirements.txt`). Include session information and package versions in outputs.
- **Keep all model inputs and outputs under version control**, with an audit trail of changes.
- **Save expensive external results as they arrive** (agent outputs and API downloads), so that a pipeline can continue without repeating completed work.
- **Before a long query or batch job, do a small trial run and read its output.**

## 5.6 Code conventions

- Follow [the style guide of the project, for example the tidyverse style guide for R or PEP 8 for Python]: consistent names, lines shorter than 80 characters, and one convention for assignment and pipes.
- Document functions with [roxygen2 comments or docstrings]. Write comments that explain the reason for the code, and leave out comments that restate the code.
- Use descriptive variable names. Define each constant once, in one file. Never write a literal count in code when a constant exists.
- Document every model assumption with a citation.
- For Python projects, use a virtual environment, a `requirements.txt` file, and `pytest`. Run local web interfaces on port [3000] unless the project specifies a different port.

---

# Part 6. Agent reports and handoffs

- **Every spawned agent saves a report in `agent-reports/`.** This rule applies to reviewers, drafters, and verifiers. Do not call an agent without having it save a report.
- Use subfolders by agent type, and descriptive file names (`<agent-type>_<task>_<date>.md`). The report contains the summary of findings, the reasoning, and the intermediate results.
- **Read the earlier reports in `agent-reports/`** before you review the same code again.
- **After a reviewer reports, address every substantive concern.** Run the reviewer again until the reviewer reports no further substantive concerns.
- **A handoff records** the output of `git status --short`, the test output, the render status, and any benchmark results.
- Record the language model and the prompt version in every report.

---

# Part 7. Project notes

[Add notes that only this project needs. Examples:]

- [The build command and the build folder.]
- [Data sources and their quirks, such as which query ranges an API accepts.]
- [Package notes: argument names, known errors, and versions.]
- [Environment notes: how to install R, pandoc, LaTeX, or Python packages in a fresh session.]
- [Sample documents that set the style for each type of deliverable.]
