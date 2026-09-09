# Context sources — checklist

Ordered by signal-to-cost. Work down the list; stop once the ACs are answerable.

## 1. Git (cheapest, highest signal — do not skip)

```bash
git log --oneline -20 -- <path>           # history of the relevant area
git log -S'<symbol>' --oneline -10        # when this symbol appeared or vanished
git blame -L <start>,<end> <file>         # who wrote this line, in which commit
git log --oneline --all --grep '<TICKET>' # has anyone already touched this ticket
```

Signals worth noticing: revert commits, several consecutive "fix" commits on the same file (an
unstable area), and the author worth asking.

## 2. Jira

**Skip this entire section when source is adhoc** (no ticket key / no Jira URL in the user input).
Record `Jira: SKIPPED (adhoc — no ticket)` and use the user message as the spec. Do not search Jira
to "find a matching ticket".

On source=jira, the description is **not** the spec. Also read:

- **Comments** — the real spec, mid-flight decisions, and QA-reported edge cases usually live here.
- **Attachments** — often the real spec: a screenshot can carry a format/UI detail no comment
  describes (an "Actual vs Expected" pair of images is frequently the *entire* spec, text is just
  a caption). Don't stop at listing filenames:
  1. Get metadata first — `fields: ["attachment"]` on the issue returns id, filename, mimeType,
     size per file.
  2. Per file: `image/*` → always download and look at it. `text/*` / `.log` → download and read
     the content. PDF/doc → try reading it; can't → record filename only. Anything else, or over
     ~10MB → record filename/type/size only, do not attempt to open it.
  3. Cap at ~5 opened per ticket. Beyond that: `Attachments: N more not analyzed, see Jira`.
  4. The download mechanism differs by which Atlassian MCP is connected — discover the capability
     (do not hardcode a tool name), download to a scratch path, never into `.work/`. No such
     capability on this MCP → record `Attachments: found N, not analyzed (no download tool on
     this MCP)` and continue. Never guess what an unopened attachment shows.
  5. Delete the downloaded file once its content is distilled into `01-context.md` — it is scratch,
     not an artifact, same as any other raw source.
  6. Every fact from one carries `[jira:TICKET#attachment-<id>]`. A fact that contradicts or adds
     to the text description is contradiction-table material (Step 4), not a footnote.
- **Issue links** — `blocks`, `is blocked by`, `relates to`, `duplicates`. A duplicated ticket often
  already contains the analysis.
- **Parent epic** — higher-level context and ACs.
- **Similar closed tickets** — find them by component/label. They reveal the pattern the team used.

Useful JQL:
`project = X AND (labels = "<label>" OR component = "<comp>") AND status = Done ORDER BY updated DESC`

## 3. Outline

- The doc linked directly from Jira.
- **Plus** a keyword search on the ticket's terms — related docs are frequently not linked.
- Read the doc's comments: the doc may be stale, and the comments are where "this changed" gets recorded.
- Always record each doc's **last-updated date** in `01-context.md`. A doc older than the most recent
  change to the code it describes is the number-one candidate for the contradiction table.

## 4. Memory (hindsight)

There may be **several servers scoped by domain** (e.g. `hindsight-conversation`, `hindsight-iam`).
Discover them dynamically — list tools matching `mcp__hindsight`, do not hardcode names. Query each
relevant scope.

- BROAD (step 2): feature name, module name, task type.
- NARROW (after step 3): exact symbol/file names, error signatures.

If a server is down, record `memory: UNAVAILABLE` and continue. Do **not** write "no known issues
here" — absence of data is not absence of problems.

## Sourcing

Every fact in `01-context.md` carries its source. Facts without one are marked `(assumption)`.
This is what lets the Reconcile step tell "the code says so" apart from "I think so".
