---
name: task-submit
description: Distills a finished /task-intake + /task-build run into Hindsight — outcomes only (who changed which function/file, who optimized, errors fixed). Recalls first; skips duplicates; updates stale rules in place without deleting past ticket work-logs. Use when the user types /task-submit, says lưu memory / tóm tắt task / submit ticket, or agrees after /task-build proposes saving. Never stores raw code, Gate B options, or plan rewrite notes. Never commits or writes to Jira.
---

# task-submit — summarize and remember

Ticket = the arguments passed to this skill if present, else the ticket key in the user message or `.work/*/04-verify.md`.

Input: `.work/<TICKET>/` from `/task-intake` + `/task-build` (`00-meta.md`, `03-plan.md`, `04-verify.md`, `journal.md`). Missing local dir → try `~/.agent-task-archive/<repo-name>/<TICKET>/`. Still missing → say so and suggest `/task-build` first.

**không cần phải lưu thẳng code, chỉ cần tóm tắt.**

## Hard prohibitions

```
FORBIDDEN: git commit / push / merge / rebase / checkout / switch / stash / clean / reset / restore
FORBIDDEN: gh pr *, glab mr *
FORBIDDEN: any Jira or Outline MCP write
FORBIDDEN: pasting function bodies, diffs, or file dumps into Hindsight
FORBIDDEN: Gate B option, intake debate, plan "change A to B" notes
FORBIDDEN: PII, tokens, .env, customer data
ALLOWED:   git status / diff --stat / log / blame / show --stat; Hindsight recall / list_memories / get_memory / update_memory / sync_retain / invalidate_memory (duplicate-only)
```

## What to store (outcomes only)

A later `/task-intake` must be able to answer: **which function/file, what is true now, who did it**.

| Unit | When | Content (no source) |
|---|---|---|
| `function-change` | a named symbol's shipped behavior | symbol, file, **result** in 1–3 sentences (what it does now), `by` |
| `bugfix-pattern` | a real error was hit and fixed | symptom → cause → fix → how to recognize; `by` |
| `optimization` | something was deleted or reused instead of added | result: what was not built / which helper absorbed it; `by` |

Skip a unit if there is nothing to say. Prefer **1–4 units**, not one essay.

**Always include author.** Resolve once in Step 1:

```
git config user.name
git config user.email
```

Empty name → `author: unknown` (do not invent). Put `by: <name>` in the body, tag `author:<name>`, metadata `author` + `author_email`. On `update_memory` of a reusable-rule: **keep** every existing `by` / author line; append the current name only if they refined it and are not already listed.

Always include: `by`, `source_ticket` (work-log), `files[]`, `symbols[]`, `HEAD` sha. First observation → `confidence: low`.

```
DO NOT STORE: Gate B / which option the user picked
DO NOT STORE: plan rewrite notes ("change A to B", "replace helper X with Y")
DO NOT STORE: intake debate, rejected options, lane, step-by-step plan
STORE: end state (function/file/rule as it is now) + who shipped or optimized it
```

**Split two kinds of fact. Never mix them in one memory.**

| Kind | Example | Lifecycle |
|---|---|---|
| `work-log` | "SLM-107: `shouldRevokeStaffSessions` — department-only staff edits do not revoke. by: Tran Ly Buu" | Append-only. New ticket → new unit. **Never invalidate** because a later optimization changed. Keep `by`. |
| `reusable-rule` | "Revoke staff sessions only on access loss. Optimized by: Tran Ly Buu" | One living unit per topic. Check first; skip / patch / add. Keep all authors when patching. |

Hindsight down → write `05-submit.md` only, record `memory: UNAVAILABLE`. Do not claim it was saved.

## Step 1 — Gather (no code dumps)

1. Read `.work/<TICKET>/04-verify.md` and `journal.md` for **what shipped**. Skim `03-plan.md` / `00-meta.md` only to list files/symbols — do not copy options or rewrite notes into memory.
2. `git config user.name` + `user.email` (author). `git log -1 --format='%h %an %s'` and `git diff --stat` on files that actually changed. Do **not** read full diffs into the retain payload.
3. List **symbols** that actually changed behavior (name + path only) and the **end-state** of each.

## Step 2 — Draft `05-submit.md`

Write `.work/<TICKET>/05-submit.md` with this shape (omit empty sections):

```markdown
# Submit: <TICKET> — <title>
HEAD: <sha>   By: <git user.name> <<email>>

## Did
- <1–5 bullets: shipped result only>

## Function changes
- `<Symbol>` (`path`) by <name>: <what is true now>

## Optimized
- by <name>: <reused Y / deleted X / did not add Z — the result, not the debate>

## Errors and fixes
- <symptom> → cause: <...> → fix: <...>  (by <name>)

## Lesson
- <reusable next time, not ticket recap>
```

Show the same summary in chat.

## Step 3 — Check, then skip / patch / add

Do this **per unit** from Step 2. Never `sync_retain` before the lookup.

1. `recall` the symbol / file / rule phrase. Also `list_memories` with `q` = that phrase or `tags` like `symbol:<Name>` / `file:<path>`.
2. If a hit has an id, `get_memory` and read the **full** text before touching it.
3. Classify the existing unit: `work-log` (names a ticket and what shipped) vs `reusable-rule` (optimization / convention / how-to-fix).

Then:

| Existing | Action |
|---|---|
| Same reusable-rule, still true | **Skip.** Do not retain a twin. |
| Same reusable-rule, stale or wrong | **`update_memory`** that `memory_id`. Change **only** the outdated sentences. Keep every ticket name, date, author line, and "what we did" paragraph. Append current `by` if they refined it. `resolve_entities=false`. |
| Existing unit is a work-log, rule is now different | **Leave the work-log.** `sync_retain` a **new** reusable-rule unit. Do not rewrite history into the old ticket. |
| No match | **`sync_retain`** a new unit. `work-log` tagged `ticket:<TICKET>`. `reusable-rule` tagged `symbol:` / `file:` (ticket tag optional as `seen_in:<TICKET>`). |
| Exact duplicate of another unit (same meaning, two ids) | **`invalidate_memory`** the extra id only, `reason` = duplicate of `<id>`. Never invalidate a work-log to "refresh" a rule. |

```
FORBIDDEN: invalidate a memory that records a past ticket's work because a later optimization changed
FORBIDDEN: update_memory that deletes unrelated sentences, other tickets, older function-change notes, or existing author lines in that unit
FORBIDDEN: sync_retain a new optimization when get_memory already has the same advice
```

If an old unit **mixes** rule + several tickets in one blob: `update_memory` to keep the historical paragraphs; put the corrected rule in a **new** reusable-rule unit. Do not wipe the blob.

New `sync_retain` payload (`context`: `work`, no source):

```
title: <specific one line>
type: function-change | bugfix-pattern | optimization | work-log
by: <git user.name>
source_ticket: <TICKET>   # omit on a reusable-rule that is not ticket-scoped
anchor:
  files: [...]
  symbols: [...]
  commit: <sha>
confidence: low
tags: [author:<name>, ...]
metadata: { author: <name>, author_email: <email> }
body: |
  by: <name>
  <end state of this unit only — no option / no plan rewrite>
```

Never write: secrets, PII, transient CI color, directory-layout facts already in the repo, Gate B options, "change A to B" plan notes.

## Step 4 — Handoff

1. List each unit: **skipped** (id + why) / **updated** (id + what sentence changed) / **added** (new title) / **invalidated** (id + duplicate-of). Or `memory: UNAVAILABLE`.
2. Add `05-submit.md` to the `00-meta.md` manifest.
3. Propose archive copy if `/task-build` has not archived yet. Ask before deleting `.work/`.
4. **Stop.** Do not commit. Do not open a PR.

## After `/task-build`

If this skill was not invoked: end the build report with one line —

> Code is in. Run `/task-submit <TICKET>` to save a Hindsight summary (who changed what, fixes, lessons — no source, no options).
