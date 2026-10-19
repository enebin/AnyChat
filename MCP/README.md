# anychat-mcp

An MCP server that guides a coding agent through adding [AnyChat](https://github.com/enebin/AnyChat), a native SwiftUI chat UI kit, to an iOS app: setup, UI customization, and backend connection.

The agent writes the code. The server reads the project, tells the agent the next step, and checks the result.

## Usage

Requires Node.js 20 or later.

Claude Code:

```bash
claude mcp add anychat -- npx -y anychat-mcp
```

Other MCP clients:

```json
{
  "mcpServers": {
    "anychat": {
      "command": "npx",
      "args": ["-y", "anychat-mcp"]
    }
  }
}
```

Then ask your agent to add AnyChat to your app.

## License

MIT
