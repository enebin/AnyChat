import assert from "node:assert/strict";
import { test } from "node:test";
import { buildDemoIndex, type SourceFile } from "../scripts/demoIndex.js";

const components = ["ChannelListView", "ChannelView"];

const showcase: SourceFile[] = [
  { path: "Showcase/ShowcaseApp.swift", text: "@main struct ShowcaseApp: App { var body: some Scene { WindowGroup { AgentDemo() } } }" },
  {
    path: "Showcase/Agent/AgentDemo.swift",
    text: [
      "import AnyChatUI",
      "",
      "/// An agent transcript. Each step is a message.",
      "/// It wraps across lines.",
      "struct AgentDemo: View {",
      "    @State private var backend = SampleChatBackend()",
      "    var body: some View { ChannelView(channel: SampleData.channel).chatBackend(backend) }",
      "}",
    ].join("\n"),
  },
  { path: "Showcase/Agent/AgentRepository.swift", text: "final class AgentRepository: ChannelRepository {}" },
  { path: "Showcase/Channel/ChannelDemo.swift", text: "/// Shows a channel.\nstruct ChannelDemo: View {\n    var body: some View { ChannelView(channel: channel) }\n}" },
  {
    path: "Showcase/ChannelState/ChannelStateDemo.swift",
    text: "/// Freezes a channel.\nstruct ChannelStateDemo: View {\n    var body: some View { ChannelView(channel: channel) }\n}",
  },
  {
    path: "Showcase/Slot/SlotDemo.swift",
    text: "/// Replaces rows.\nstruct SlotDemo: View {\n    var body: some View { ChannelListView() }\n}",
  },
];

const shared: SourceFile[] = [
  { path: "Shared/SampleChatBackend.swift", text: "@MainActor\nfinal class SampleChatBackend: ChatBackend {}\n\nenum SampleData {}" },
  { path: "Shared/SamplePoll.swift", text: "nonisolated struct SamplePoll: Hashable, Sendable {}" },
];

function demo(name: string) {
  const found = buildDemoIndex(showcase, shared, components).demos.find((entry) => entry.name === name);
  assert.ok(found);
  return found;
}

test("each Showcase folder is a demo holding every file in it", () => {
  // Given
  const files = showcase;

  // When
  const index = buildDemoIndex(files, shared, components);

  // Then
  assert.deepEqual(index.demos.map((entry) => entry.name), ["Agent", "Channel", "ChannelState", "Slot"]);
  assert.deepEqual(demo("Agent").files, ["Showcase/Agent/AgentDemo.swift", "Showcase/Agent/AgentRepository.swift"]);
});

test("a demo whose name starts another demo's name keeps only its own folder", () => {
  // Given, When
  const channel = demo("Channel");

  // Then
  assert.deepEqual(channel.files, ["Showcase/Channel/ChannelDemo.swift"]);
});

test("a demo's description is the first sentence of its view's doc comment", () => {
  // Given
  const name = "Agent";

  // When
  const description = demo(name).description;

  // Then
  assert.equal(description, "An agent transcript.");
});

test("an attribute line between a demo view's doc comment and its declaration is skipped", () => {
  // Given
  const files: SourceFile[] = [
    { path: "Showcase/Typing/TypingDemo.swift", text: "/// Shows typing.\n@MainActor\nstruct TypingDemo: View {}" },
  ];

  // When
  const index = buildDemoIndex(files, shared, components);

  // Then
  assert.equal(index.demos[0]?.description, "Shows typing.");
});

test("a demo view without a doc comment fails the index", () => {
  // Given
  const files: SourceFile[] = [{ path: "Showcase/Typing/TypingDemo.swift", text: "struct TypingDemo: View {}" }];

  // When, Then
  assert.throws(() => buildDemoIndex(files, shared, components), /Showcase\/Typing: the TypingDemo view needs a \/\/\/ comment/);
});

test("a demo registers a backend when its files call chatBackend", () => {
  // Given, When
  const [agent, slot] = [demo("Agent"), demo("Slot")];

  // Then
  assert.equal(agent.registersBackend, true);
  assert.equal(slot.registersBackend, false);
});

test("a demo shows the component views its files name", () => {
  // Given, When
  const [agent, slot] = [demo("Agent"), demo("Slot")];

  // Then
  assert.deepEqual(agent.components, ["ChannelView"]);
  assert.deepEqual(slot.components, ["ChannelListView"]);
});

test("the Shared types a demo uses are its stand-ins, and the app file belongs to no demo", () => {
  // Given
  const index = buildDemoIndex(showcase, shared, components);

  // When
  const agent = demo("Agent");

  // Then
  assert.deepEqual(agent.standIns, ["SampleChatBackend", "SampleData"]);
  assert.ok(index.demos.every((entry) => !entry.files.includes("Showcase/ShowcaseApp.swift")));
});
