---
name: "step-loop"
description: Runs one step sub-issue to completion. Implements it, then repeats verify → review → fix until the review leaves no confirmed 🔴/🟠, logging each round on the issue. Use for "run step #N", "continue #N", or when another skill hands over an implemented step.
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Skill, Agent, AskUserQuestion
argument-hint: <sub-issue number> [--implemented]
---

Drive one step to its done criteria. The rules are in `AGENTS.md` "작업 진행" and "테스트 / 검증".

## 1. Load context

- `gh issue view <N> --comments`, then the parent issue it belongs to.
- Read `AGENTS.md`, `ARCHITECTURE.md`, the sub-documents under `docs/architecture/` in scope, and the code in scope.
- If a step listed in "Depends on" is still open and its branch is not available, stop and say so.
- Earlier round comments on the issue tell you where the last session stopped. Continue from there.

## 2. Branch

Never work on `main`. Use `step/<N>-<short-slug>`. Branch from `main` when every dependency is merged, otherwise from the dependency step's branch. Reuse the branch if it already exists.

## 3. Implement

Skip this section if `--implemented` is given; the caller has already done it.

- Follow the issue's "Implementation notes" first. If they say another procedure or skill does the implementation, use it.
- Write the tests `AGENTS.md` "테스트 / 검증" requires together with the code.

## 4. Loop

Repeat for round `r = 1, 2, 3`:

1. **Verify.** Run the verification commands in `AGENTS.md` that the change affects. For QuickStart UI tests, run only the tests that cover the changed screens with `-only-testing` (`AGENTS.md` "UI 테스트"); the full suite runs once in step 5. For UI-affecting SDK or demo changes, invoke `/ui-qa` and pass it the `.xcresult` path, commit, and dirty state of that run so QA does not rerun the same tests (`AGENTS.md` "Independent UI QA"). Do not run another UI driver on its simulator while QA runs. On failure, the implementation agent fixes the root cause and sends the affected checks back to QA on a fresh build. Verification failures do not count as a round. Missing required QA evidence is reported as blocked/unverified, not as a pass.
   - In round 2 or later, skip UI tests and UI QA when the fixes since the last UI QA PASS touch nothing under `Sources/AnyChatUI/`, `Sources/AnyChatDesignSystem/`, or `Examples/`. Log UI QA as `not rerun — no UI change since round <r>`.
2. **Review.** Invoke `/sdk-review` in local mode.
3. **Decide.**
   - Required UI QA is blocked and cannot be unblocked within the authorized scope → report the blocker and stop without marking the step complete. Do not consume review rounds by repeating unchanged blocked checks.
   - Verification passed, required UI QA passed, and no confirmed 🔴/🟠 → go to step 5. Non-UI work has no UI QA requirement.
   - Otherwise fix only the confirmed 🔴/🟠. Leave 🟡, nits, and UNVERIFIED items for the log.
   - If the report has trade-offs or high-impact UNVERIFIED items, ask the user before acting on them.
4. **Log** the round as an issue comment:

```markdown
### Round <r>
- Verify: <pass / what failed and how it was fixed>
- UI QA: <PASS / FAIL / BLOCKED / not applicable> — <evidence paths or reason>
- Review: 🔴 <n> / 🟠 <n> / 🟡 <n> confirmed
- Fixed: <one line per fixed finding>
- Left: <🟡, nits, UNVERIFIED — one line each>
```

If round 3 ends with confirmed 🔴/🟠 still open, stop and ask the user how to proceed.

## 5. Finish

1. If the step changed anything under `Sources/AnyChatUI/`, `Sources/AnyChatDesignSystem/`, or `Examples/`, run the full QuickStart UI test suite once. A failure sends you back to step 4 and counts as a verification failure, not a round.
2. Tick the satisfied "Done when" boxes in the issue body (`gh issue edit <N> --body-file`).
3. If the step produced a decision that later steps need, append it to the parent issue's "Decisions". Structural decisions go into `ARCHITECTURE.md` or its sub-documents instead.
4. Post a closing comment: what was done, anything left, the branch name.
5. Commits and pushes happen only when the user asks (`AGENTS.md` "Git / GitHub"). Offer a commit and a PR whose body includes `Closes #<N>`.
