# CodeGraph (CLI + MCP + project index)

100% local code knowledge graph. No API key.  
([colbymchenry/codegraph](https://github.com/colbymchenry/codegraph))

| | |
| --- | --- |
| CLI | `codegraph` on `PATH` |
| Project index | `.codegraph/` (gitignored) |
| MCP | stdio: `codegraph serve --mcp` |
| Init | once per repo, from that repo's root |

Skip a step when it already succeeded. Do **not** commit `.codegraph/`. Do **not** run `codegraph install` without `--yes` (it prompts).

### Agent (one-time CLI + this repo)

Run from the **repo root**. Detect the client (**Cursor** or **Claude Code**).

**1. Install CLI** — skip if `command -v codegraph` works

```bash
curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
```

Windows (user on PowerShell): `irm https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.ps1 | iex`

Node already on the machine: `npm i -g @colbymchenry/codegraph` is fine.

The installer may not refresh this shell. If `codegraph` is missing after install: `export PATH="$HOME/.local/bin:$PATH"` (or open a new terminal). Upgrade later: `codegraph upgrade`.

**2. Wire MCP** — skip if a `codegraph` server is already in the user's MCP config

Prefer **user-scope** (`--location=global`). Do not commit a project `.mcp.json` just for CodeGraph.

```bash
# Cursor
codegraph install --yes --target=cursor --location=global

# Claude Code
codegraph install --yes --target=claude --location=global
```

Both clients on this machine: `--target=cursor,claude`.

If the installer is unavailable, merge into `~/.cursor/mcp.json` (do not drop other servers):

```json
"codegraph": {
  "type": "stdio",
  "command": "codegraph",
  "args": ["serve", "--mcp", "--path", "${workspaceFolder}"]
}
```

Claude Code fallback:

```bash
claude mcp add --transport stdio codegraph -- codegraph serve --mcp
```

Ask the user: **Settings → MCP → codegraph** off/on (or Restart MCP). Claude Code: new session after install.

**3. Init this project** — skip if `.codegraph/` already exists and `codegraph status` looks healthy

```bash
grep -qxF '.codegraph/' .gitignore 2>/dev/null || echo '.codegraph/' >> .gitignore
codegraph init
```

`codegraph init` creates `.codegraph/` and builds the graph. Do **not** pass `-i` (deprecated; indexing is the default). If the index exists but looks stale: `codegraph sync`.

Do **not** `codegraph init` on `$HOME` or `/` unless the user asked (`--force` only then).

### User

1. Toggle / restart MCP after the agent wires config.
2. Nothing else. No keys. Optional UI: `codegraph ui` → http://127.0.0.1:4747

### Smoke test

```bash
command -v codegraph
codegraph status
```

Then from MCP: `codegraph_explore` with a symbol or question from this repo (e.g. a known service name). If the tool says **CodeGraph not initialized**, rerun step 3.

Done when: CLI is on `PATH`, `.codegraph/` exists, `codegraph status` prints graph stats, and CodeGraph MCP tools load.

Uninstall CLI + agent wiring: `codegraph uninstall`. Drop this project's index only: `codegraph uninit`.
