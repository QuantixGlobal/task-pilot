---
name: task-intake
description: Research a Jira ticket or a free-form user request and produce a user-approved plan BEFORE any code is written. Use when the user types /task-intake with a ticket key (ABC-123), a Jira link, or a direct task in any language with no ticket ("làm cho tôi...", "add ..."). Never edits code, never commits, never writes to Jira or Outline.
---

# task-intake — from ticket or direct request to approved plan

Research phase. Ends with `03-plan.md`. **No code is written here.**

Input = `$ARGUMENTS` if present, else the rest of the user message after `/task-intake`.

## Source — classify before any Jira call

**jira** when the input contains a ticket key (`[A-Z][A-Z0-9]+-\d+`, e.g. `SLM-107`) or a Jira /
browse / `selectedIssue=` URL. Extra words next to a key still count as **jira** (the user is
annotating that ticket). Folder: the ticket key.

**adhoc** when there is no ticket key and no Jira URL — a direct order in any language.
Examples: `/task-intake làm cho tôi abc...`, `/task-intake add session invalidation on role change`.
Folder: `adhoc-<slug>` from the request (lowercase, hyphenated, ≤40 chars). The user message **is**
the spec. Quote it verbatim in `01-context.md` as `[user]`.

```
FORBIDDEN on adhoc: getJiraIssue, JQL, Jira search, "maybe this maps to a ticket", asking for a key
REQUIRED on adhoc:  treat the user text as the only product spec; Jira = SKIPPED (adhoc — no ticket)
```

Do not invent a project key from the first word. `SLM` alone is not a ticket. If the request is too
vague to write ACs, Gate A — ask what to build, not which ticket.

| Source | Jira | Outline | Git / memory / codegraph |
|---|---|---|---|
| **jira** | full gather (description, comments, links, epic, similar) | linked doc + keyword search | always |
| **adhoc** | skip — do not probe or query | optional keyword search if the request names a feature | always |

## Hard prohibitions

```
FORBIDDEN: git commit / push / merge / rebase / checkout / switch / stash / clean / reset / restore
FORBIDDEN: gh pr *, glab mr *
FORBIDDEN: any Jira MCP write (comment, transition, edit) or Outline write
FORBIDDEN: editing any source file
ALLOWED:   git status / diff / log / blame / show / ls-files, all MCP reads
```

The working tree is usually dirty. `stash` and `checkout` will destroy the user's work — and those
are exactly the two commands an agent invents to "get a clean baseline". Don't.

## Minimum change

The best plan is the one that writes the least new code. Applies to every option, every step in
`03-plan.md`, and the trivial-lane shortcut.

Understand first, then climb. After Locate has the real flow, **then** stop at the first rung
that holds — do not invent a new file or layer before checking these:

1. Does this need to exist at all? (not in the ACs → out of scope)
2. Does it already exist here? Reuse the helper, util, or pattern — do not propose a rewrite.
3. Does the standard library already do this?
4. Does a native platform feature cover it?
5. Does an already-installed dependency solve it?
6. Can this be one line / one existing function?
7. Only then: the minimum new code that works.

**Bug fix = root cause, not symptom.** A ticket names a symptom. The recommended option must fix
the shared function every caller uses. Planning a patch on only the path the ticket mentions
leaves a sibling caller still broken.

```
FORBIDDEN: proposing a new file / package / interface / helper an AC did not require
FORBIDDEN: proposing a new dependency when stdlib, an existing helper, or an installed lib covers it
FORBIDDEN: boilerplate, wrappers, or "for later" hooks in the plan
REQUIRED:  fewest files, shortest working diff, deletion over addition, boring over clever
```

When two options are the same size, pick the edge-case-correct one — less code is not a flimsier
algorithm. Question a complex option out loud: "Do you actually need X, or does existing Y cover
it?" If you catch yourself planning a file or layer that existing code already covers, drop it
before Gate B — do not offer it as a serious option.

An intentional simplification in the plan must name the ceiling and the upgrade path (in Scope /
Do not add, not as a future ticket).

Not optional to plan for: input validation at trust boundaries, error handling that prevents data
loss, security, anything the ticket explicitly asked for. Non-trivial logic plans ONE runnable
check (the smallest test that fails if the logic breaks). Trivial one-liners need no test.

| Excuse | Reality |
|---|---|
| "Cleaner if we extract a helper" | Extract only if an AC requires it or a third copy already exists. |
| "We'll need this later" | Not in the ACs → out of scope. |
| "A wrapper matches our style" | Reuse the existing call site. One extra planned file is a miss. |
| "Smallest plan is this one caller" | Sibling callers stay broken. Plan the shared-function fix. |
| "The bigger option is more complete" | Completeness = ACs covered, not extra layers. |

**Red flags — drop the option before Gate B:** a create-file step with no AC that requires a new
file; a new interface / factory / layer the ticket did not ask for; a planned copy of a helper
that already lives in the repo; steps that exist only for comments, TODOs, or future-proofing.

## Artifacts

Write to `.work/<TICKET>/`:

| File | Contents |
|---|---|
| `00-meta.md` | source (`jira` \| `adhoc`), ticket or `adhoc-<slug>`, branch, base ref, lane, capability matrix, MCP availability, manifest |
| `01-context.md` | spec (Jira or verbatim user request) + Outline + git history + memory, distilled |
| `02-analysis.md` | contradiction table, ACs, edge cases, planned test cases |
| `03-plan.md` | execution plan — the input to `/task-build` |

Before creating the first file:

```bash
grep -qxF '.work/' "$(git rev-parse --git-dir)/info/exclude" || echo '.work/' >> "$(git rev-parse --git-dir)/info/exclude"
```

Use `.git/info/exclude`, **not** `.gitignore`.

Check `~/.agent-task-archive/<repo-name>/<TICKET>/` first: if artifacts from an earlier run exist
(possibly from Claude Code), ask whether to resume or research again.

## Step 0 — Preflight

1. Current branch and base ref: run `bash .cursor/task-workflow/scripts/changed-files.sh`, read the
   `# base=...` line on stderr and **confirm the base is correct**.
2. **Capability detection** → [capability-detection.md](../../task-workflow/capability-detection.md).
   Probe; never assume a toolchain. Record the command matrix in `00-meta.md`.
3. **CodeGraph preflight**: no `.codegraph/` → `codegraph init .`; otherwise → `codegraph sync .`.
   Once per session, before the first codegraph call.
4. **MCP availability probe** — Outline, `hindsight-*` (there may be several domain scopes),
   codegraph: cheapest read on each. Probe Jira **only on source=jira**. On failure, record
   `UNAVAILABLE (reason)` in `00-meta.md` and **continue**. Never invent content for a dead source.
   On adhoc, record `Jira: SKIPPED (adhoc — no ticket)` and do not call it.

## Step 1 — Triage lane

- **trivial** — text/config/one function, no behavior change → skip steps 2–4, write a short `03-plan.md`.
- **standard** — the default, run everything.
- **complex** — contract/schema/event change, multiple services, migration → add operational risk,
  Gate C mandatory.

When torn, pick the heavier lane.

## Step 2 — Gather → `01-context.md`

Full checklist: [context-sources.md](../../task-workflow/context-sources.md).

- **Git first**: `git log` / `blame` over the relevant area.
- **Spec**: **jira** → description **plus comments, attachments, issue links, parent epic, similar
  closed tickets**. **adhoc** → the user message only; record `Jira: SKIPPED (adhoc — no ticket)`.
- **Outline**: **jira** → the linked doc **plus** a keyword search. **adhoc** → keyword search only
  if the request names a feature; otherwise skip. Record each doc's last-updated date.
- **Memory (BROAD)**: recall by module/feature name and task type.

Prefer a gather subagent when available; require it to return **the content of `01-context.md`**,
not a raw dump. Otherwise read → **distill straight into the file**. Do not keep raw source in the
conversation. Every fact carries a source (`[JIRA-123#comment-4]`, `[git:abc1234]`, `[outline:slug]`,
`[memory:<id>]`); without one, mark it `(assumption)`.

## Step 3 — Locate

Call `codegraph_explore` **before** grep/read — one call returns verbatim source, call paths, and
blast radius. Extract: relevant symbols, call paths, caller counts, existing helpers/utils that
could absorb the change, areas with no test coverage.

Only then do the **second memory recall (NARROW)**, keyed on the exact symbol/file names just found.

## Step 4 — Reconcile → `02-analysis.md`

| # | Topic | Spec says (Jira or user) | Doc says | Code does | Conflict? | Recommendation |
|---|---|---|---|---|---|---|

Plus: **numbered ACs** (`AC-1`…, each observable), **edge cases** (justified from the code),
**test cases mapped 1-to-1 to ACs**, and **open questions** (specific, each with a default).

### GATE A — Ambiguity

A blocking open question → **stop, ask the user, wait**. Number the options in chat. Do not guess.
Do not comment on a Jira ticket. On adhoc, do not ask for a ticket key.

## Step 5 — Design

Climb the minimum-change ladder before writing options. Two or three options: approach,
files/symbols touched (mark each as **reuse** or **create**), trade-offs, risks, blast radius,
rough diff size. Prefer the option with the fewest new files, no new dependency, and the
shortest working diff.

State your recommendation and why (include what you are **not** adding). Lane `complex` also
covers backward compatibility, migration, rollback, feature flag.

### GATE B — Approach

Number the options, ask the user to choose, **wait**.

### GATE C — Blast radius

Triggers when the change touches a symbol with many callers **or** an area with no test coverage.
State the actual numbers, propose writing a failing test from the ACs first, wait for confirmation.

## Step 6 — `03-plan.md`

```markdown
# Plan: <TICKET> — <title>
Source: <jira|adhoc>   Lane: <...>   Base ref: <...>   Chosen option: <...>

## Scope
In scope: ...
OUT of scope (found but deliberately untouched): ...
Reuse: <existing symbols/files this plan edits instead of creating>
Do not add: <abstractions / files / deps rejected as unnecessary>

## Steps
1. [ ] <action> — file: `path` (reuse|create) — covers: AC-1

## Tests
| AC | Test case | Test file | Kind (unit/integration/manual) |

## Verification
<this project's actual build / lint / unit / integration / sonar commands, from 00-meta.md>

## Drift threshold
Stop and re-plan if: a file outside the list must change, a new file or abstraction is needed that this plan did not list, more than 2 steps deviate, or an AC is wrong.

## Rollback
<this workflow never commits — usually a list of files to revert by hand>
```

## Step 7 — Handoff

Summarize in chat: contradictions found, chosen option, scope, step count, files reused vs
created, what you refused to add, biggest risk, which sources were SKIPPED. Then tell the user
to run `/task-build <TICKET>`, then `/task-submit <TICKET>` after the code is done.

**Stop here. Do not write code.**
