---
groundwork: 1

language:
  conversation: ko
  artifacts: en

project:
  summary: "A backend-agnostic native SwiftUI chat UI kit (SPM library AnyChatUI) for messaging apps and AI agents, plus an npx MCP server that guides a customer's coding agent through integration."
  stack: [swift, swiftui, ios, spm, typescript, mcp]
  kind: library

docs:
  rules: AGENTS.md
  architecture: ARCHITECTURE.md

tracker:
  type: github
  owner: enebin
  repo: AnyChat

workflow:
  bundle: step-loop
  autoland: false
  worktree: true

branches:
  strategy: develop-release
  integration: develop
  production: main
  work_prefix: step
  merge: squash

verification:
  base: ci-gate
  addons: [design-fidelity, api-contract]
  commands:
    - name: Package build
      run: "xcodebuild build -scheme AnyChat -destination 'platform=iOS Simulator,name=iPhone 17 Pro'"
      verified: true
    - name: Package tests
      run: "xcodebuild test -scheme AnyChat -destination 'platform=iOS Simulator,name=iPhone 17 Pro'"
      verified: true
    - name: Showcase build
      run: "cd Examples/QuickStart && xcodegen generate && xcodebuild build -project QuickStart.xcodeproj -scheme Showcase -destination 'platform=iOS Simulator,name=iPhone 17 Pro'"
      verified: true
    - name: MCP tests
      run: "cd MCP && npm ci && npm test"
      verified: true
    - name: MCP catalog check
      run: "cd MCP && npm run catalog:check"
      verified: true
  ui_paths:
    - Sources/AnyChatUI/
    - Sources/AnyChatDesignSystem/
    - Examples/
  ui_tests:
    targeted: "cd Examples/QuickStart && xcodegen generate && xcodebuild test -project QuickStart.xcodeproj -scheme QuickStart -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:{test}"
    full: "cd Examples/QuickStart && xcodegen generate && xcodebuild test -project QuickStart.xcodeproj -scheme QuickStart -destination 'platform=iOS Simulator,name=iPhone 17 Pro'"
  design_source: docs/design/messages/README.md
  ui_coverage: docs/ui-coverage.md

architecture:
  bundle: unidirectional

review:
  bundle: sdk
  reviewers: [architecture, code-quality, dx]
  release_qa: true
  skeptic: blocking
  trigger: per-round
  personas:
    - name: App developer
      goal: "Show the chat screens with one `import AnyChatUI` line and adjust them with themes, slots, and options."
      kind: developer
    - name: Messaging app user
      goal: "Find a channel, read its messages, and reply, react, or retry a failed send."
      kind: user

qa:
  bundle: release

mode: normal
---

## Review focus: architecture

- Standard: `ARCHITECTURE.md`, the touched documents under `docs/architecture/`, and the `AGENTS.md` sections "제품 방향", "Public API 규율", "동시성", and "아키텍처 작업 원칙".
- Direction `Presentation → Domain ← adapter`: `AnyChatCore` never imports SwiftUI; DesignSystem atoms never take domain concepts (channel, message); screen-level compositions stay out of DesignSystem.
- Backend neutrality: no backend SDK types, server rules, or branching on channel kind inside the package; no type names that reveal a channel kind.
- Access levels match the table in `ARCHITECTURE.md` section 2; `Reducer` / `State` / `Store` / `RowState` stay internal.
- Isolation defaults from section 3; no `nonisolated(unsafe)` or `@unchecked Sendable`; new classes in `AnyChatUI` / `AnyChatDesignSystem` declare `nonisolated deinit {}`.
- Reducer / Store contract from section 6; no generic `Store<R>` or shared `Reducer` protocol.
- Injection per section 7: the backend only through `chatBackend(_:)`, everything else through initializers; no global registries, singletons, or DI containers.
- A structural change updates `ARCHITECTURE.md` or its sub-document first.

## Review focus: code-quality

- Standard: the `AGENTS.md` sections "핵심 원칙", "동시성", "아키텍처 작업 원칙", and "테스트 / 검증"; `ARCHITECTURE.md` sections 6 and 8; the touched documents under `docs/architecture/screens/`.
- Late completion of a cancelled Task overwriting state, missing Task replacement, stream termination, duplicate or missing pages, the empty list and the last page.
- A new generation / epoch / token identifier used to tell results apart is a rule violation.
- SwiftUI cost: an unstable `id`, heavy work or formatter creation in `body`, observing more state than the view needs.
- Tests: reducer tests cover the normal, ignored, failure, and late-completion case for each input; store tests cover effect execution, Task replacement, late completion, and stream consumption; Given / When / Then; no `Task.sleep`; no real backend; shared constants instead of repeated literals.

## Review focus: dx

- Primary evidence is a call site in `Examples/QuickStart`. If none exists, write a few lines of one and judge from that.
- Customization reach: themes and slots can handle size, layout, and live-changing content (streaming text). Report what blocks it, not what is merely not built in.
- MCP sync: a change to screens, initializers, slots, callbacks, themes, options, doc comments, domain models, or the backend boundary updates `MCP/` in the same PR, per the table in `docs/architecture/mcp.md`, and regenerates `MCP/catalog/components.json`.
- New public symbols have a `///` doc comment and a `- Since:` tag.
- Naming: no channel-kind names, no two- or three-letter type prefixes, acronyms stay uppercase (`channelURL`, `userID`).
- Suggest an overload or convenience API only when a real call site is awkward today.
- End-user accessibility (VoiceOver, Dynamic Type) is out of scope for now.

## UI QA notes

- App: `Examples/QuickStart` with its in-memory sample backend (no account, no network). Run `xcodegen generate`, then build and run the `QuickStart` scheme on the "iPhone 17 Pro" simulator (iOS 26.4). The `Showcase` scheme shows themes, slots, and streaming text.
- Launch environment: `QUICKSTART_CUSTOMIZATION_DEMO=0` for the default appearance, `1` for customization flows. Keep the two in separate evidence.
- Create state through the UI. Do not seed it with `UserDefaults` launch arguments (`-key value`).
- A simulator signed in to an Apple account can show system alerts that intercept taps; dismiss them by position, because button titles are localized.
- QA gets exclusive use of its simulator, and reuses the implementer's `.xcresult` when its commit and dirty state match the current tree.

## Notes

- GitHub closes issues on merge: no — integration branch is not the default branch.
- Integration branch `develop` was created from `main` for the develop-release workflow.
- CI runs on pull requests and on pushes to `main`; pull requests into `develop` get CI, which the CI gate relies on.
- CI's `mcp` job runs `MCP tests` and `MCP catalog check`, as the Public API contract rule requires.
- Full UI suite at onboarding (`main` d860575): 51 passed, 1 skipped (`testPickingAPhotoSendsIt`: the iOS 26 simulator cannot load picked photos), 1 failed. `testSwitchingToDarkRedrawsAnOpenChannel` fails on CI and on a fresh simulator; its cause is not yet investigated. Run UI tests with the simulator's hardware keyboard off (I/O > Keyboard > Connect Hardware Keyboard); with it on, the software keyboard never rises and the keyboard tests fail.
- Architecture follows the existing `ARCHITECTURE.md`, which matches the unidirectional bundle; onboarding added only the minimal-structure block.
- QA is release: before each release, `ui-qa --full` and `ux-review --full` (Messaging app user) run on the release candidate. `review.release_qa: true` is its compatibility mirror.
