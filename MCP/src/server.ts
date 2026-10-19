import { existsSync } from "node:fs";
import { dirname, isAbsolute, join, relative, resolve } from "node:path";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import {
  readCatalog,
  readPlacementExample,
  renderComponent,
  renderComponentList,
  renderUnknownComponent,
} from "./catalog.js";
import { readDemoFile, readDemoIndex, renderDemo, renderUnknownDemo } from "./demos.js";
import { renderAddPackage, renderGetStarted, repositoryURL } from "./guide.js";
import { addPackage, type PackageSource } from "./packageLink.js";
import { inspectProject } from "./project.js";
import { sdkVersion } from "./version.js";

const instructions = `AnyChat is a backend-neutral SwiftUI chat UI kit for iOS 18+.
To set it up in the user's app, call get_started with the absolute path of the app's directory.
Do the one step it returns, then call get_started again; repeat until every step is done.
When a step says to call another tool, call it instead of editing project files by hand.
To place or customize one component, such as the channel screen, call list_components, then describe_component with its name.
For a working screen that combines parts, such as an agent-style chat, call show_demo with a demo that describe_component lists.
Write code exactly as the steps and the component descriptions show it and do not guess API names.`;

export function createServer(): McpServer {
  const server = new McpServer({ name: "anychat", version: sdkVersion }, { instructions });
  const catalog = readCatalog();
  const demoIndex = readDemoIndex();

  server.registerTool(
    "get_started",
    {
      title: "Get started with AnyChat",
      description:
        "Inspects the user's iOS project and returns the AnyChat setup steps with the status of each and the instructions for the next one. Call it first, and again after finishing each step.",
      inputSchema: {
        projectPath: z
          .string()
          .describe("Absolute path of the app's directory, its .xcodeproj, or its Package.swift."),
        uiTests: z
          .boolean()
          .optional()
          .describe("The user's answer to whether to add a chat UI test. Omit it until get_started asks for it, then pass the same answer on every call."),
      },
    },
    async ({ projectPath, uiTests }) => {
      if (!isAbsolute(projectPath)) {
        return errorResult(`projectPath must be absolute, but got \`${projectPath}\`.`);
      }
      return textResult(renderGetStarted(inspectProject(projectPath), projectPath, sdkVersion, uiTests));
    },
  );

  server.registerTool(
    "add_package",
    {
      title: "Add the AnyChat package to an Xcode project",
      description:
        "Links the AnyChatUI package product into an app target of an .xcodeproj by editing project.pbxproj safely. Changes nothing when the target already links it. Call it when get_started says so.",
      inputSchema: {
        projectPath: z.string().describe("Absolute path of the app's .xcodeproj."),
        targetName: z
          .string()
          .optional()
          .describe("The target to link. Omit it when the project has one app target."),
        packagePath: z
          .string()
          .optional()
          .describe(
            "Absolute path of a local checkout of the AnyChat package, to link it by path instead of by its repository URL. Use it only when the user asks for a local checkout.",
          ),
      },
    },
    async ({ projectPath, targetName, packagePath }) => {
      if (!isAbsolute(projectPath)) {
        return errorResult(`projectPath must be absolute, but got \`${projectPath}\`.`);
      }
      if (packagePath !== undefined && !(isAbsolute(packagePath) && existsSync(join(packagePath, "Package.swift")))) {
        return errorResult(`packagePath must be the absolute path of a directory with a Package.swift, but got \`${packagePath}\`.`);
      }
      const xcodeprojPath = resolve(projectPath);
      const source: PackageSource = packagePath === undefined
        ? { kind: "remote", url: repositoryURL, minimumVersion: sdkVersion }
        : { kind: "local", relativePath: relative(dirname(xcodeprojPath), resolve(packagePath)) };
      return textResult(renderAddPackage(addPackage(xcodeprojPath, source, targetName), xcodeprojPath, sdkVersion));
    },
  );

  server.registerTool(
    "list_components",
    {
      title: "List AnyChat components",
      description:
        "Lists the AnyChat UI components, such as the channel list and the channel screen, with one line about each. Call describe_component with a name for its details.",
      inputSchema: {},
    },
    async () => textResult(renderComponentList(catalog)),
  );

  server.registerTool(
    "describe_component",
    {
      title: "Describe a AnyChat component",
      description:
        "Returns one AnyChat component's public API, generated from the SDK: what it needs before it can appear, its initializers, slots, callbacks, settings, theme, and options, the values its slots receive and the types they use, each with its declaration and documentation, and an example of where it goes in an app.",
      inputSchema: {
        name: z.string().describe("The component's name as list_components returns it, such as `ChannelView`."),
      },
    },
    async ({ name }) => {
      const component = catalog.components.find((entry) => entry.name === name);
      if (!component) {
        return errorResult(renderUnknownComponent(catalog, name));
      }
      const demos = demoIndex.demos.filter((demo) => demo.components.includes(component.name));
      return textResult(renderComponent(catalog, component, readPlacementExample(component.name), demos));
    },
  );

  server.registerTool(
    "show_demo",
    {
      title: "Show a AnyChat demo",
      description:
        "Returns the source of one Showcase demo, a working screen built from public API only, such as an agent transcript or streaming text. Read it as a reference for combining slots, themes, and custom content; describe_component lists the demos for each component.",
      inputSchema: {
        name: z.string().describe("The demo's name as describe_component lists it, such as `Agent`."),
      },
    },
    async ({ name }) => {
      const demo = demoIndex.demos.find((entry) => entry.name === name);
      if (!demo) {
        return errorResult(renderUnknownDemo(demoIndex, name));
      }
      return textResult(renderDemo(demo, readDemoFile));
    },
  );

  return server;
}

function textResult(text: string) {
  return { content: [{ type: "text" as const, text }] };
}

function errorResult(text: string) {
  return { isError: true, content: [{ type: "text" as const, text }] };
}
