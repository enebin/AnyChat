import assert from "node:assert/strict";
import { test } from "node:test";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { readDemoFile, readDemoIndex } from "../src/demos.js";
import { createServer } from "../src/server.js";
import { sdkVersion } from "../src/version.js";
import { Fixture } from "./support/fixtures.js";

async function connectedClient(): Promise<Client> {
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  const client = new Client({ name: "test", version: "0.0.0" });
  await Promise.all([createServer().connect(serverTransport), client.connect(clientTransport)]);
  return client;
}

function text(result: Awaited<ReturnType<Client["callTool"]>>): string {
  const [first] = result.content as { type: string; text: string }[];
  return first!.text;
}

test("the server tells the agent to start with get_started", async () => {
  // Given
  const client = await connectedClient();

  // When
  const instructions = client.getInstructions();
  const { tools } = await client.listTools();

  // Then
  assert.match(instructions ?? "", /call get_started/);
  assert.deepEqual(tools.map((tool) => tool.name), ["get_started", "add_package", "list_components", "describe_component", "show_demo"]);
});

test("get_started guides the agent through the project it inspects", async () => {
  // Given
  const client = await connectedClient();
  const root = Fixture.directory({
    "App.xcodeproj/project.pbxproj": Fixture.pbxproj({ deploymentTargets: ["18.0"] }),
  });

  // When
  const first = await client.callTool({ name: "get_started", arguments: { projectPath: root } });
  const answered = await client.callTool({ name: "get_started", arguments: { projectPath: root, uiTests: false } });

  // Then
  assert.equal(first.isError, undefined);
  assert.match(text(first), new RegExp(`AnyChatUI ${sdkVersion.replaceAll(".", "\\.")} setup`));
  assert.match(text(first), /## Next step: 1\. Ask whether to add a chat UI test/);
  assert.match(text(answered), /## Next step: 3\. Add the AnyChatUI package/);
});

test("get_started rejects a relative path", async () => {
  // Given
  const client = await connectedClient();

  // When
  const result = await client.callTool({ name: "get_started", arguments: { projectPath: "App" } });

  // Then
  assert.equal(result.isError, true);
  assert.match(text(result), /must be absolute/);
});

test("add_package links the package into the project it is given", async () => {
  // Given
  const client = await connectedClient();
  const project = Fixture.xcodeProject("synchronized");

  // When
  const result = await client.callTool({ name: "add_package", arguments: { projectPath: `${project}/` } });

  // Then
  assert.equal(result.isError, undefined);
  assert.match(text(result), /Linked the `AnyChatUI` product into the `App` target/);
});

test("add_package rejects a relative project path or a package path without a manifest", async () => {
  // Given
  const client = await connectedClient();
  const project = Fixture.xcodeProject("synchronized");

  // When
  const results = await Promise.all([
    client.callTool({ name: "add_package", arguments: { projectPath: "App.xcodeproj" } }),
    client.callTool({ name: "add_package", arguments: { projectPath: project, packagePath: project } }),
  ]);

  // Then
  assert.deepEqual(results.map((result) => result.isError), [true, true]);
  assert.match(text(results[0]!), /projectPath must be absolute/);
  assert.match(text(results[1]!), /packagePath must be the absolute path of a directory with a Package\.swift/);
});

test("list_components lists the components of the shipped catalog", async () => {
  // Given
  const client = await connectedClient();

  // When
  const result = await client.callTool({ name: "list_components", arguments: {} });

  // Then
  assert.equal(result.isError, undefined);
  assert.match(text(result), /^- `ChannelListView`: /m);
  assert.match(text(result), /^- `ChannelView`: /m);
});

test("describe_component describes a component with its placement example", async () => {
  // Given
  const client = await connectedClient();

  // When
  const result = await client.callTool({ name: "describe_component", arguments: { name: "ChannelView" } });

  // Then
  assert.equal(result.isError, undefined);
  assert.match(text(result), /^# `ChannelView`/);
  assert.match(text(result), /init\(channel: ChatChannel\)/);
  assert.match(text(result), /## Placement example\n[\s\S]*ChannelView\(channel: channel\)/);
});

test("describe_component returns the known names for an unknown component", async () => {
  // Given
  const client = await connectedClient();

  // When
  const result = await client.callTool({ name: "describe_component", arguments: { name: "ChatView" } });

  // Then
  assert.equal(result.isError, true);
  assert.match(text(result), /The components are `ChannelListView`, `ChannelView`\./);
});

function packedDemos() {
  const { demos } = readDemoIndex();
  assert.ok(demos.length > 0, "npm test packs the Showcase demos before it runs");
  return demos;
}

test("describe_component lists every packed demo that uses the component", async () => {
  // Given
  const client = await connectedClient();
  const expected = packedDemos().filter((demo) => demo.components.includes("ChannelView"));

  // When
  const result = await client.callTool({ name: "describe_component", arguments: { name: "ChannelView" } });

  // Then
  const demos = text(result).split("## Demos")[1] ?? "";
  assert.ok(expected.length > 0);
  for (const demo of expected) {
    assert.ok(demos.includes(`\n- \`${demo.name}\`: ${demo.description}`), demo.name);
  }
});

test("show_demo returns a packed demo's source and the known demos for an unknown name", async () => {
  // Given
  const client = await connectedClient();
  const demos = packedDemos();
  const [first] = demos;
  const unknownName = demos.map((demo) => demo.name).join("");

  // When
  const [known, unknown] = await Promise.all([
    client.callTool({ name: "show_demo", arguments: { name: first!.name } }),
    client.callTool({ name: "show_demo", arguments: { name: unknownName } }),
  ]);

  // Then
  assert.equal(known.isError, undefined);
  for (const path of first!.files) {
    assert.ok(text(known).includes(`## \`${path}\`\n\n\`\`\`swift\n${readDemoFile(path).trimEnd()}\n\`\`\``), path);
  }
  assert.equal(unknown.isError, true);
  for (const demo of demos) {
    assert.ok(text(unknown).includes(`- \`${demo.name}\`: ${demo.description}`), demo.name);
  }
});
