---
name: ui-qa
description: Delegate rendered UI and interaction verification to the independent ui-qa agent after UI changes or when the user requests screen QA. Uses the task's design source and actual app evidence; does not replace code review.
---

# UI QA

Use the canonical agent definition at `.claude/agents/ui-qa.md`, resolved from the repository root. If you are already acting as the QA agent, follow that definition directly instead of spawning another agent.

## Delegate

Prepare a short assignment with:

- Absolute worktree path, relevant diff/files, and the current build state.
- User requirements and the specified design source, including available local references.
- Affected screens, required states/actions, and demo mode (default or customization).
- Available simulator/device, test commands/results, and artifact paths with their provenance. Include the `.xcresult` of the UI tests already run on this build, with its commit and dirty state, so QA reuses it instead of rerunning them.
- An output directory outside tracked source, and any execution constraints.

Spawn one fresh QA subagent using the registered `ui-qa` role when supported. In Claude, use the `ui-qa` agent defined under `.claude/agents`. In Codex, use `.codex/agents/ui-qa.toml`; if the current tool surface cannot select custom roles, spawn a fresh subagent and explicitly instruct it to read and follow `.claude/agents/ui-qa.md`. Inherit model settings. Pass the requirements and evidence, not the implementer's conclusion or proposed diagnosis.

Reserve the assigned simulator for QA until it returns. Do not drive that simulator or change the target UI while QA runs; independent non-UI work may continue. If delegation is unavailable, disclose that limitation instead of claiming independent QA.

## Act on the result

Preserve the QA status, evidence paths, and coverage limits in the user-facing result. The implementation agent fixes defects and adds or repairs regression tests, then returns the affected checks to QA on a fresh build. A blocked check remains unverified; never relabel it PASS. Stop and report a repeated blocker when no independent work remains.

This workflow tests rendered behavior. Keep the existing `sdk-review` / Skeptic Review workflow for code-review findings; do not relabel visual observations as completed code review.
