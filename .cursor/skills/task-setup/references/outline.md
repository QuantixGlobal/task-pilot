# Outline MCP

Workspace MCP: `https://quantix-global.getoutline.com/mcp`  
Auth: OAuth **or** API key header `Authorization: Bearer ol_api_...`  
([Outline MCP docs](https://docs.getoutline.com/s/guide/doc/mcp-6j9jtENNKL))

### User (both clients)

1. Create an API key: [https://quantix-global.getoutline.com/settings/api-and-access](https://quantix-global.getoutline.com/settings/api-and-access)
2. Send the key to the agent (`ol_api_...`). Do not paste it into a tracked file.

Claude Code can skip the key and use `/mcp` OAuth instead. API key is more reliable if OAuth fails.

### Cursor

**Agent** (after the key arrives) — merge into `~/.cursor/mcp.json`, do not drop other servers:

```json
"outline": {
  "url": "https://quantix-global.getoutline.com/mcp",
  "headers": {
    "Authorization": "Bearer ol_api_..."
  }
}
```

Ask the user: **Settings → MCP → outline** off/on (or Restart MCP).

### Claude Code

OAuth (no key):

```bash
claude mcp add --transport http outline https://quantix-global.getoutline.com/mcp
```

Then `/mcp` → Outline login.

API key (after user sends `ol_api_...`):

```bash
claude mcp add --transport http outline https://quantix-global.getoutline.com/mcp \
  --header "Authorization: Bearer ol_api_..."
```

If the CLI has no `--header`, merge the same JSON block as Cursor into user-scope Claude MCP config (`claude mcp add-json` or `~/.claude.json`). Restart the session.

### Smoke test

`list_collections` query `SLM` → `fetch` one document.

Done when: Outline tools load and one page body returns.

### No MCP — Outline REST

User still creates the key at the link above and sends `ol_api_...`. Agent calls REST (no MCP write):

```bash
curl -sS -X POST https://quantix-global.getoutline.com/api/documents.search \
  -H "Authorization: Bearer ol_api_..." \
  -H "Content-Type: application/json" \
  -d '{"query":"SLM","limit":5}'
```

Read one doc:

```bash
curl -sS -X POST https://quantix-global.getoutline.com/api/documents.info \
  -H "Authorization: Bearer ol_api_..." \
  -H "Content-Type: application/json" \
  -d '{"id":"<document-id-or-urlId>"}'
```

Prefer MCP in an interactive session. Use REST when MCP is down, or for scripts/CI.
