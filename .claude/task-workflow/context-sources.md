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
- **Attachments** — screenshots, designs, logs.
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
