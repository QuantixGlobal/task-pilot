# Memory policy — write little, write right

This is the most failure-prone part of the whole workflow. A wrong or noisy memory is **worse than no
memory**: it gets recalled forever, reinforces itself, and skews every later task. The default is
**do not write**.

## Three-condition filter — all three must hold

1. **Surprising** — you expected A and got B. If everything went according to plan, there is nothing
   to record.
2. **Not derivable** — not readable from the code, git log, README, CLAUDE.md, or a function
   signature. "Function X takes 3 arguments" is already in the code. "X must be called after the
   transaction commits, otherwise it reads stale data" is not.
3. **Reusable** — it will help on a *different* task, not just this ticket.

If all three do not hold, leave it in `journal.md` (which travels with the archive) and move on.

## Never write

- Customer data, PII, or real message content pulled from Jira/Outline.
- Tokens, credentials, connection strings, `.env` contents.
- Transient state: "CI is red today", "the branch is dirty".
- Anything already in the repo: directory layout, conventions already stated in CLAUDE.md.
- Unverified guesses. If it is not confirmed, use `confidence: low` — or do not write it.

## Schema

```yaml
title: <one line, specific — "Redis pipeline in wspool is not atomic", NOT "notes about Redis">
type: pitfall | convention | decision | domain-fact
anchor:
  files: [service/user/update_user.go]
  symbols: [upsertAccountUpdates]
  commit: <sha at the time of learning>
confidence: low | medium | high
evidence: <concrete — command output, file:line, log>
body: |
  Expected: ...
  Actual: ...
  How to avoid next time: ...
source_ticket: <TICKET>
```

`anchor` is mandatory. A memory without one can never be invalidated and becomes permanent noise.

## Confidence and escalation

- First observation → `low`.
- Confirmed again on a different task → raise to `medium`, **update the existing memory**, do not
  create a second one.
- Third confirmation, or direct confirmation by the user → `high`.

Only `high` memories may be acted on without re-checking.

## On recall: verify the anchor before trusting it

A memory reflects the state at the time it was written. Before applying it:

1. Do the anchored files/symbols still exist? (`codegraph_explore`, or `git show`)
2. Has that area changed since `anchor.commit`? (`git log <sha>..HEAD -- <file>`)

Still present and unchanged → trust it per its confidence. Substantially changed → treat it as a hint
to re-verify, and after verifying, **update it or mark it superseded**. If you find a memory is wrong,
fix it in that same session — this is the only self-cleaning mechanism the system has.

## Deduplication

Before writing, recall using your intended `title`. If something close already exists, **update it**
(raise confidence, add anchors) instead of adding a second entry. Duplicates dilute recall.

## Multiple scopes

Hindsight may expose several servers split by domain. Write to the scope matching the module you
touched. If it is unclear which, ask the user — do not write to both.
