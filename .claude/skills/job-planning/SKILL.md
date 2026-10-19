---
name: "job-planning"
description: Splits a job that does not fit in one PR into steps, and after approval creates a parent issue plus one sub-issue per step in the repository's GitHub Issues. Use for "plan this job", "split this into issues", or when another skill hands off a large job.
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
argument-hint: <requirement | issue number> [--context <text or file>]
---

Turn a job into a parent issue and step sub-issues. This skill **only plans and creates issues.** Running a step is the job of `step-loop`.

Rules for how work proceeds live in `AGENTS.md` "작업 진행". If this skill and the repo docs disagree, follow the repo docs.

## 1. Gather context

- Read `AGENTS.md`, `ARCHITECTURE.md`, the sub-documents under `docs/architecture/` the job touches, `Package.swift`, and the code the job touches.
- If the argument is an issue number, read it with `gh issue view <N> --comments` and use it as the parent issue instead of creating a new one.
- If `--context` is given, it comes from the caller. Carry its per-step instructions into the matching sub-issue's "Implementation notes" as written. Do not interpret or expand them.

## 2. Split

- If the job fits in one PR, make one issue with no parent and skip the sub-issues.
- Each step must build, pass the verification commands, and be reviewable on its own.
- Size a step so one review loop can cover it: one PR a reviewer can read in one sitting.
- If the job changes structure, the first step is the `ARCHITECTURE.md` / `docs/architecture/` update (`AGENTS.md` "핵심 원칙").
- Order steps by dependency and write each step's dependencies down.
- Do not add steps for work nobody asked for. Ask when the requirement leaves a choice open (`AGENTS.md` "핵심 원칙": ask when there are several technical options).
- When the user moves something to a later scope while answering, set it aside as a **needs-planning issue**. Only record what the user moved out. Do not add your own ideas.

## 3. Preview and get approval

Show the user the parent issue and every step: title, goal, scope (in / out), done criteria, dependencies. List the needs-planning issues too, with title and start condition. Explain the split in one or two sentences. **Create nothing before the user approves.** Apply requested changes and show the preview again.

## 4. Create the issues

1. Check the GitHub account as `AGENTS.md` "Git / GitHub" says.
2. Create the parent issue (unless one was given) with `gh issue create`.
3. Create each sub-issue the same way, in step order, titled `<Parent short name>: <step>`. Do not number titles; the parent's Steps list holds the order, so adding or dropping a step does not rename the others.
4. Link each sub-issue to the parent:

```bash
CHILD_ID=$(gh api repos/{owner}/{repo}/issues/<child number> --jq .id)
gh api -X POST repos/{owner}/{repo}/issues/<parent number>/sub_issues -F sub_issue_id=$CHILD_ID
```

5. Create each needs-planning issue with `gh issue create --label "needs planning"`. Do not link it as a sub-issue: sub-issues are the steps that finish the parent, so a parked item would keep the parent open forever. Point back with `Split from #<parent>` in its body.
6. Report the parent link, the sub-issue numbers in order, and the needs-planning issue numbers.

Write issue text in English.

### Parent issue body

```markdown
## Goal
<what the finished job delivers, in two or three sentences>

## Context
<why now; links to relevant ARCHITECTURE.md / AGENTS.md sections>

## Steps
<ordered list; sub-issues track progress>

## Decisions
<empty at first; append decisions as they are made>
```

### Sub-issue body

```markdown
## Goal
<one or two sentences>

## Scope
- In: ...
- Out: ...

## Depends on
<#numbers, or "none">

## Implementation notes
<caller-provided instructions, or "none">

## Done when
- [ ] Verification commands in AGENTS.md pass
- [ ] Review leaves no confirmed 🔴/🟠
- [ ] <step-specific criteria>
```

### Needs-planning issue body

When its start condition is met, run `job-planning <issue number>` on it.

```markdown
Split from #<parent>

## What
<the work, in one or two sentences>

## Why not now
<the reason the user gave>

## Start when
<the condition that makes it worth planning>

## Decisions so far
<answers already given during planning, or "none">
```
