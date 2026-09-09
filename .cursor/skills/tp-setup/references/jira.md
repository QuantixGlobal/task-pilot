# Jira MCP

Official remote server: `https://mcp.atlassian.com/v2/mcp`  
([Atlassian Rovo MCP](https://github.com/atlassian/atlassian-mcp-server))

### Cursor

**User**

1. In Cursor chat: `/add-plugin atlassian`
2. Complete the Atlassian browser OAuth prompt.

**Agent** (after user says auth is done): run smoke test below.

### Claude Code

```bash
claude mcp add --transport http atlassian https://mcp.atlassian.com/v2/mcp
```

Then in a Claude Code session: `/mcp` → authenticate Atlassian in the browser.

Do **not** use the legacy SSE URL `https://mcp.atlassian.com/v1/sse` (retired after 30 June 2026).

### Smoke test

1. `atlassianUserInfo` + `getAccessibleAtlassianResources`
2. `searchJiraIssuesUsingJql` with `assignee = currentUser()`

Done when: Atlassian tools are available and a ticket list returns.
