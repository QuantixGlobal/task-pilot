# Hindsight (local Docker or existing host + MCP)

Self-hosted agent memory. MCP is always at `{HINDSIGHT_URL}/mcp/` (multi-bank) or `{HINDSIGHT_URL}/mcp/{bank_id}/` (one bank).  
([Installation](https://hindsight.vectorize.io/developer/installation), [Models](https://hindsight.vectorize.io/developer/models), [MCP](https://hindsight.vectorize.io/developer/mcp-server))

Do **not** invent keys. Do **not** commit tokens.

| | Local Docker | Already running |
| --- | --- | --- |
| `HINDSIGHT_URL` | `http://localhost:8888` | User-supplied (no trailing slash) |
| Agent does | Probe first; if already up → bank + MCP only. Else LLM + Docker + bank + MCP | Bank (if reachable) + MCP only |
| UI | `http://localhost:9999` | Their host (often `:9999`) |
| Secrets | `$HOME/.hindsight/local.env` | None in this repo; optional Bearer they already use |

### Agent — ask first

**Q1 (hard gate).** Do not start Docker and do not ask for an LLM key until this is answered:

> Install Hindsight **locally** (Docker on this machine), or point MCP at an instance **already running** somewhere?

- **local** → **Probe this machine first** (below). Do not ask Q2 and do not write env / run Docker until the probe says nothing is running.
- **existing** → ask `HINDSIGHT_URL` (example `https://hindsight.example.com`). If their API/MCP is locked, also ask for the Bearer token. Skip LLM + Docker. Go to **Bank + MCP**.

Ask **one question at a time**.

### Local probe (Q1 = local — do this before Q2)

Check whether Hindsight is **already running on this machine**. Reuse it. Do not reinstall.

```
FORBIDDEN: ask for an LLM key when localhost:8888/health already succeeds
FORBIDDEN: docker rm / docker run / rewrite local.env when a local instance is already up
FORBIDDEN: treat "local" as "always install from scratch"
```

**1. Health**

```bash
curl -sf http://localhost:8888/health
```

**2. Container** (if health is not 200 yet)

```bash
docker ps --filter name=^hindsight$ --format '{{.Names}} {{.Status}}'
```

| Probe result | Next step |
|---|---|
| `/health` is 200 | Skip Q2 and **Local install**. Tell the user it is already running. Go to **Bank + MCP** with `HINDSIGHT_URL=http://localhost:8888`. |
| Container `hindsight` is running, health not ready | Do **not** `docker rm`. Wait for health (same loop as start). Then **Bank + MCP**. |
| Neither | Ask Q2 (LLM), then **Local install**, then **Bank + MCP**. |

Changing provider or key on an instance that is already up is a **reconfigure** request — only then `docker rm -f hindsight` and rerun. `/tp-setup` local does not reconfigure by default.

---

### Local install (only if Q1 = local **and** the probe found nothing running)

Docker Desktop must already be running. First image pull is large (~3.7 GB ARM / ~9 GB AMD).

Hindsight has **no native Cerebras provider**. Cerebras is OpenAI-compatible: `HINDSIGHT_API_LLM_PROVIDER=openai` + `HINDSIGHT_API_LLM_BASE_URL=https://api.cerebras.ai/v1`.

**Q2.** Do not assume Cerebras, OpenAI, or any key already on disk:

> Which LLM should Hindsight use?  
> `cerebras` · `openrouter` · `gemini` (Google AI Studio) · `openai` · `anthropic` · `groq` · `other` (OpenAI-compatible URL)

Then ask for the **API key** (and a model name only if they want to override the default below). User sends the key in chat. Do not paste it into a tracked file.

| Choice | User creates key | `PROVIDER` | Extra env | Default model |
| --- | --- | --- | --- | --- |
| **cerebras** | [Cerebras Cloud](https://cloud.cerebras.ai) (`csk-...`) | `openai` | `HINDSIGHT_API_LLM_BASE_URL=https://api.cerebras.ai/v1` | `gpt-oss-120b` |
| **openrouter** | [OpenRouter keys](https://openrouter.ai/keys) (`sk-or-...`) | `openrouter` | — | `qwen/qwen3.5-9b` |
| **gemini** | [Google AI Studio](https://aistudio.google.com/apikey) | `gemini` | — | `gemini-2.0-flash` |
| **openai** | [OpenAI API keys](https://platform.openai.com/api-keys) (`sk-...`) | `openai` | — | `gpt-4o` |
| **anthropic** | [Anthropic console](https://console.anthropic.com/settings/keys) (`sk-ant-...`) | `anthropic` | — | `claude-sonnet-4-20250514` |
| **groq** | [Groq console](https://console.groq.com/keys) (`gsk-...`) | `groq` | — | `openai/gpt-oss-20b` |
| **other** | Their vendor console | `openai` | Ask for `BASE_URL` (must end in `/v1`) + `MODEL` | (user supplies) |

This section is skipped when the **Local probe** already found a running instance. Changing provider or key: `docker rm -f hindsight` then rerun — the volume keeps memory data.

**1. Write secrets** (after the key arrives)

```bash
mkdir -p "$HOME/.hindsight" "$HOME/.hindsight-docker"
# Replace the four values from the table + the user's key / optional model override.
cat > "$HOME/.hindsight/local.env" <<'EOF'
HINDSIGHT_API_LLM_PROVIDER=openai
HINDSIGHT_API_LLM_BASE_URL=https://api.cerebras.ai/v1
HINDSIGHT_API_LLM_API_KEY=csk-xxxx
HINDSIGHT_API_LLM_MODEL=gpt-oss-120b
HINDSIGHT_API_WORKER_ID=hindsight-local
EOF
# Omit HINDSIGHT_API_LLM_BASE_URL for native providers (openrouter, gemini, openai, anthropic, groq).
chmod 600 "$HOME/.hindsight/local.env"
```

Cerebras example above matches a working local setup. Other providers: copy only the rows they need from the table.

**2. Start container** — skip if `curl -sf http://localhost:8888/health` already succeeds

```bash
# Bind mount must be UID 1000 (image user). Named volume also works if chown is not possible.
# macOS bind mounts are usually fine; Linux: sudo chown -R 1000:1000 "$HOME/.hindsight-docker"
docker rm -f hindsight 2>/dev/null || true
docker run -d --pull always --name hindsight --restart unless-stopped --shm-size=1g \
  -p 8888:8888 -p 9999:9999 \
  --env-file "$HOME/.hindsight/local.env" \
  -v "$HOME/.hindsight-docker:/home/hindsight/.pg0" \
  ghcr.io/vectorize-io/hindsight:latest
for i in $(seq 1 60); do
  curl -sf http://localhost:8888/health >/dev/null && break
  sleep 5
done
curl -sf http://localhost:8888/health
```

Do **not** use `-it` from an agent (blocks). First boot can take several minutes while models load.

If start fails with `Permission denied` on `.pg0`: `sudo chown -R 1000:1000 "$HOME/.hindsight-docker"` and rerun. Do not `docker run --user` — the image only has UID 1000.

Then **Bank + MCP** below. Stop later: `docker rm -f hindsight` (volume stays). Wipe memory: also `rm -rf "$HOME/.hindsight-docker"`.

---

### Bank + MCP (both paths)

`HINDSIGHT_URL` is `http://localhost:8888` (local) or the URL they gave (existing). No trailing slash. If they sent a Bearer token, add `-H "Authorization: Bearer …"` to curl and the same header on the MCP server.

Ask: **what is the project name?** (one bank per project). Suggest `basename "$PWD"`; do not invent `slm-conversation` or any other leftover name.

```bash
HINDSIGHT_URL="${HINDSIGHT_URL:-http://localhost:8888}"
PROJECT_NAME="<user answer or basename $PWD>"
BANK_ID=$(printf '%s' "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')
curl -sS -X PUT "${HINDSIGHT_URL}/v1/default/banks/${BANK_ID}" \
  -H "Content-Type: application/json" -d '{}'
```

If the existing host is read-only or bank create fails, still wire MCP — they may already have the bank.

Prefer **single-bank** MCP so tools do not take `bank_id`. Merge into `~/.cursor/mcp.json`, do not drop other servers:

```json
"hindsight": {
  "url": "<HINDSIGHT_URL>/mcp/<BANK_ID>/"
}
```

Ask the user: **Settings → MCP → hindsight** off/on (or Restart MCP).

Multi-bank (only if they want several projects on one MCP):

```json
"hindsight": {
  "url": "<HINDSIGHT_URL>/mcp/"
}
```

Claude Code (single-bank):

```bash
claude mcp add --transport http hindsight "${HINDSIGHT_URL}/mcp/${BANK_ID}/"
```

### User

1. Answer **local vs existing**. Local: the agent probes this machine first. Only if nothing is running, send LLM choice + API key. Existing: send the API URL (and Bearer if required).
2. Name the project (or accept the folder name).
3. Toggle the `hindsight` MCP server after the agent writes config.
4. Local only: do not open http://localhost:9999 unless they want the UI.

### Smoke test

```bash
curl -sf "${HINDSIGHT_URL}/health"
curl -sf "${HINDSIGHT_URL}/v1/default/banks/${BANK_ID}"
```

Then from MCP: `recall` (or a test `retain`) — bank is implicit from the URL.

Done when: `/health` is 200 (or MCP tools load if health is firewalled), that bank is usable, and Hindsight MCP tools load.

Local image embeddings/rerank stay in-container. Only the **LLM** (retain / reflect / consolidation) hits the provider chosen at install. Existing hosts already have their own LLM — do not reconfigure it from this setup.
