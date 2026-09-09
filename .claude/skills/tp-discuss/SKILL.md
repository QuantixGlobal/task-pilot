---
name: tp-discuss
description: Answer questions about the codebase, its architecture, past decisions, or documented process by pulling from CodeGraph, Hindsight memory, and Outline — read-only, no code written, no ticket, no plan. Use when the user asks an open question in any language ("tại sao...", "chỗ này nằm ở đâu", "giải thích...", "explain how X works", "why did we...") without asking to build or fix anything. Never writes code, never edits files, never writes to Jira/Outline/Hindsight, never produces .work/ artifacts.
---

# tp-discuss — ask the codebase, the docs, and the memory

Input = the arguments passed to this skill if present, else the rest of the user message after
`/tp-discuss`.

Conversational Q&A. No `.work/` artifacts, no plan, no code. If the conversation turns into
"let's build this", stop and point at `/tp-intake` instead — this skill never plans or edits files.

```
FORBIDDEN: editing any file, git commit/push, any Jira/Outline/Hindsight write
FORBIDDEN: producing a plan or .work/<TICKET>/ artifacts — that is /tp-intake's job
FORBIDDEN: guessing when a source has nothing — say "not found", never invent
ALLOWED:   codegraph_explore, git log/blame/show, Outline read/search, Hindsight recall
```

No update check here (unlike `/tp-intake`) — this skill is for quick, repeated back-and-forth
within one session; a network check on every question would add latency for no benefit.

## Classify the question, then fetch — don't fan out to all three every time

| Question shape | Source, in order |
|---|---|
| "Where is X / what calls Y / blast radius of Z" | **CodeGraph** first — `codegraph_explore` returns verbatim source + call paths in one call |
| "Why did we... / is there a gotcha with... / what's the convention for..." | **Hindsight** recall, by module/feature/symbol name |
| "What's the process / architecture / design decision for..." | **Outline** — linked doc plus a keyword search |
| No `.codegraph/` index, or the area predates it | `git log` / `blame` / `show` on the relevant path |

Try the best-matching source first. Add a second source only if the first didn't answer it — most
questions need one, not three. A server that's down, or no `.codegraph/`: say so and fall back to
the next source; don't stall the conversation on it.

## Answer with sources, surface conflicts

Every claim carries its source inline: `[codegraph:file:line]`, `[git:sha]`, `[outline:slug]`,
`[hindsight:<id>]`. Two sources disagree (doc says X, code does Y) → say both, and which is more
likely current — never silently pick one. Nothing found anywhere → say that plainly, don't guess.

## Handoff

Answer reveals a real task ("so we should fix/add this") → say so and suggest `/tp-intake`. Do not
start planning or editing files here.

```
/tp-discuss vì sao module auth lại tách riêng session store?
/tp-discuss explain how the retry queue works
```
