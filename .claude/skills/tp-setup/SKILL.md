---
name: tp-setup
description: Install and wire Jira MCP, Outline MCP, local SonarQube, Hindsight memory, and CodeGraph for this machine/repo. Use when the user types /tp-setup or /agent-setup, asks to cài đặt / setup / install MCP, or names Jira, Outline, SonarQube, Hindsight, or CodeGraph as something to configure. Do not invent API keys. Do not commit tokens.
---

# tp-setup

Agent **installs and wires config**. User **creates API keys / completes OAuth**, then sends credentials back.

Tools = the arguments passed to this skill if present (e.g. `hindsight`, `jira outline`), else ask **which** to set up. One at a time unless they said `all`.

| Token | Meaning |
|---|---|
| Jira | ticket MCP |
| Outline | wiki MCP |
| SonarQube / Sonar | quality scan |
| Hindsight | long-term agent memory |
| CodeGraph | local code graph |

## Hard rules

```
FORBIDDEN: invent API keys / tokens / passwords
FORBIDDEN: commit secrets, .sonar/, .codegraph/, $HOME/.hindsight/local.env
FORBIDDEN: write keys into a tracked repo .mcp.json
```

Detect the client (**Cursor** or **Claude Code**), then follow that client's block in the reference.

| Client | MCP config | How to add a server |
|---|---|---|
| **Cursor** | `~/.cursor/mcp.json` | Plugin marketplace, or merge JSON, then **Settings → MCP** toggle |
| **Claude Code** | `claude mcp add` | CLI, then `/mcp` in a session to auth |

Prefer **user-scope** (home dir). Skip a step when it already succeeded. After wiring MCP, ask the user to toggle the server off/on.

Ask **one question at a time**. Do not start Docker or write env files until the hard-gate questions in that reference are answered.

## Procedure

1. Confirm client + which tool(s).
2. **Read only** the matching file, then execute it:
   - Jira → [references/jira.md](references/jira.md)
   - Outline → [references/outline.md](references/outline.md)
   - SonarQube → [references/sonarqube.md](references/sonarqube.md)
   - Hindsight → [references/hindsight.md](references/hindsight.md)
   - CodeGraph → [references/codegraph.md](references/codegraph.md)
3. Run that file's smoke test. Report pass/fail + what the user must toggle.
4. If `all`, do them in order: Jira → Outline → SonarQube → Hindsight → CodeGraph (Hindsight and Sonar ask questions mid-flow — wait).
5. Hindsight **local**: probe the machine first. If Hindsight is already running, skip install — go straight to bank + MCP.
