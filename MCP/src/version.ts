import { readFileSync } from "node:fs";

// The server ships with the SDK release of the same number, so this is also the SDK version it guides.
export const sdkVersion: string = JSON.parse(
  readFileSync(new URL("../../package.json", import.meta.url), "utf8"),
).version;
