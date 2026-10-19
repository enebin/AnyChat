---
name: "sdk-review"
description: Runs the architecture, code quality, and SDK DX reviewers in parallel, merges their findings, verifies them with Skeptic Review, and reports. Does not modify code.
allowed-tools: Bash, Read, Grep, Glob, Agent, Skill
argument-hint: [<PR number> | <path>] [--only arch,quality,dx]
---

Review a change from three angles. This skill **only reports.** Fixing is the job of other skills such as `review-and-fix`.

| Key | Agent | Angle |
|---|---|---|
| `arch` | `architecture-reviewer` | Layers · coupling · isolation · Reducer/Store contract · premature abstraction |
| `quality` | `code-quality-reviewer` | Correctness bugs · readability · algorithms · render cost · tests |
| `dx` | `sdk-dx-reviewer` | Public API usability · customization reach · compatibility · docs |

## 1. Parse arguments

Split `$ARGUMENTS` on whitespace.

- If `--only <key,...>` is present, run only those reviewers. Stop and say so if a key is unknown. Otherwise run all three.
- If the first remaining token is a number, use **PR mode**. If it is a path, use **path mode**. If there is none, use **local mode**.

## 2. Decide what to review

Each mode sets `DIFF_CMD` (the command that shows the change) and `READ_HINT` (how to read file contents).

- **Local mode.** `BASE=$(git merge-base main HEAD)`. `DIFF_CMD = git diff $BASE`, which includes uncommitted changes. `READ_HINT` is "read files from the working tree". Find new untracked files with `git ls-files --others --exclude-standard` and add them to the list.
- **PR mode.** Run `git fetch origin main pull/<N>/head`, then `HEAD_SHA=$(git rev-parse FETCH_HEAD)` and `BASE=$(git merge-base origin/main $HEAD_SHA)`. `DIFF_CMD = git diff $BASE $HEAD_SHA`. Do not touch the working tree (no `gh pr checkout`). `READ_HINT` is "read with `git show $HEAD_SHA:<path>`".
- **Path mode.** Review every file under the path, with no diff. The targets are `git ls-files <path>`. There is no `DIFF_CMD`, and `READ_HINT` is "read files from the working tree".

Build the changed-file list with `$DIFF_CMD --stat`. If the list is empty, say there is nothing to review and stop.

## 3. Run the reviewers in parallel

Launch the chosen reviewers with `Agent` **at the same time, in one message**. Do not paste the diff body into the prompt; reviewers read it themselves with `DIFF_CMD`. Put the following, identically, into every prompt.

```
Target: <mode> (<PR number / path / local changes against main>)
View the change: <DIFF_CMD, or "none — review whole files">
Read files: <READ_HINT>
Changed files:
<file list>

Do not modify code. Use only read-only git commands.

Reporting rules:
- Attach one piece of evidence to every finding: a section name in AGENTS.md / ARCHITECTURE.md, or a concrete failure scenario (which input or state leads to what going wrong).
- Drop any finding you cannot back with evidence. Also drop anything the compiler already prevents.
- Report only problems the change created. Report a pre-existing problem only if the change made it worse.
- Keep matters of taste separate as nits. Do not give them a severity.
- If you have no findings, write only "No findings".

Output format (per finding):
### <severity> <one-line summary>
- Location: <file:line>
- Evidence: <doc section or failure scenario>
- Suggestion: <direction of the fix; code snippet only when needed>

Severity:
- 🔴 Critical: breaks the build, behavior, or the public contract, or locks in structure that is hard to undo
- 🟠 Major: a rule violation or a defect that must be fixed before merge
- 🟡 Minor: worth fixing but does not block merge
```

## 4. Merge the results

- Merge findings that point at the same `file:line` or the same cause. Keep the higher severity and list every source reviewer.
- When reviewers pull in opposite directions (for example, DX wants a convenience API and architecture calls it YAGNI), do not pick a side. Collect these under "Trade-offs" with both sides' evidence next to each other.
- If a reviewer failed or returned something abnormal, note it in the report. Do not rerun it.

## 5. Skeptic Review

If there is at least one merged 🔴/🟠 finding, invoke the `skeptic-review:skeptic-review` skill **exactly once**. Pass only the 🔴/🟠 findings along with the target information. 🟡 findings do not block merge, so verifying them would not change what happens next; they stay unverified. If there are no 🔴/🟠 findings, do not invoke it. If Skeptic Review is unavailable, do not substitute another verification.

This repo-level exception narrows the global "verify every finding" rule on purpose: Skeptic runs cost minutes per review round, and most rounds report only 🟡.

## 6. Report

Put the Skeptic Review status line at the top.

- If it ran: `SkepticReview: APPLIED — CONFIRMED <n> / UNVERIFIED <n> / REJECTED <n>`
- If there were no findings: `SkepticReview: NOT RUN — no first-pass findings`
- If there were only 🟡 findings: `SkepticReview: NOT RUN — no blocking findings`
- If it was unavailable: `SkepticReview: OFF`

Then, in this order:

1. **Conclusion in one or two sentences.** Whether anything blocks merge.
2. **Findings.** Only CONFIRMED 🔴/🟠, by severity. Prefix each title with `[CONFIRMED]` and the source reviewer (`arch` / `quality` / `dx`). If Skeptic Review did not run, list the merged 🔴/🟠 as they are, without the prefix.
3. **Needs confirmation.** Only high-impact UNVERIFIED ones. Prefix each title with `[UNVERIFIED]` and add one line on what could not be confirmed.
4. **Unverified minor.** Every 🟡, prefixed with `[UNVERIFIED]` and the source reviewer. These were not sent to Skeptic Review.
5. **Trade-offs.** If any.
6. **Nits.** If any, one line each.

Leave REJECTED findings out of the report.
