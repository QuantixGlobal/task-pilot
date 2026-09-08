---
name: task-build
description: Execute an approved plan from /task-intake — write the code, run verification (build, lint, unit, integration, and Sonar scoped to files changed on this branch), report against acceptance criteria, then propose /task-submit for Hindsight memory. Use when the user types /task-build, or when 03-plan.md exists and they say to start implementing (any language). Never commits, never pushes, never opens a PR, never writes to Jira.
---

# task-build — execute, verify, distill

Ticket = `$ARGUMENTS` if present, else the ticket key in the user message.

Input: `.work/<TICKET>/03-plan.md`, produced by `/task-intake`.
No plan → say so and suggest `/task-intake` first. For a genuinely small change, ask permission
to write a minimal plan inline and continue. The same minimum-change rules below apply to that
inline plan: reuse first, fewest files, no extra layers.

## Hard prohibitions

```
FORBIDDEN: git commit / push / merge / rebase / checkout / switch / stash / clean / reset / restore
FORBIDDEN: gh pr *, glab mr *
FORBIDDEN: any Jira or Outline MCP write
FORBIDDEN: rm -rf, git clean — including during artifact cleanup (step 8)
ALLOWED:   git status / diff / log / blame / show / ls-files
```

`stash` and `checkout` destroy a dirty working tree. Use
`bash .cursor/task-workflow/scripts/changed-files.sh` for scope.

## Minimum change

The best code is the code never written. Applies to every plan tweak and every edit.

Understand first, then climb. Read the task and the code it touches, trace the real flow end to
end, **then** stop at the first rung that holds:

1. Does this need to exist at all?
2. Does it already exist here? Reuse the helper, util, or pattern — do not rewrite it.
3. Does the standard library already do this?
4. Does a native platform feature cover it?
5. Does an already-installed dependency solve it?
6. Can this be one line?
7. Only then: the minimum code that works.

**Bug fix = root cause, not symptom.** A report names a symptom. Find every caller of the function
you touch and fix the shared function once. Patching only the path the ticket names leaves a
sibling caller still broken.

```
FORBIDDEN: new file / package / interface / helper the plan did not require
FORBIDDEN: new dependency when stdlib, an existing helper, or an installed lib covers it
FORBIDDEN: boilerplate, wrappers, or "for later" hooks
REQUIRED:  fewest files, shortest working diff, deletion over addition, boring over clever
```

When two approaches are the same size, pick the edge-case-correct one — less code is not a
flimsier algorithm. Question a complex plan step: "Do you actually need X, or does existing Y
cover it?" If the plan itself adds files or layers that existing code already covers, **stop,
simplify `03-plan.md`, tell the user** — do not implement the extra.

Mark an intentional simplification with a comment that names the ceiling and the upgrade path.

Not optional: input validation at trust boundaries, error handling that prevents data loss,
security, anything the ticket explicitly asked for. Non-trivial logic leaves ONE runnable check
behind (the smallest test that fails if the logic breaks). Trivial one-liners need no test.

| Excuse | Reality |
|---|---|
| "Cleaner if I extract a helper" | Extract only if the plan required it or a third copy already exists. |
| "We'll need this later" | Not in the ACs → do not build it. |
| "A wrapper matches our style" | Reuse the existing call site. One extra file is a miss. |
| "Smallest patch is this one caller" | Sibling callers stay broken. Fix the shared function. |

**Red flags — stop and delete the extra:** new file not in `03-plan.md`; new interface / factory /
layer the ticket did not ask for; a copy of a helper that already lives in the repo; a diff that
grows from comments, TODOs, or future-proofing.

## Step 1 — Preflight

1. Read `00-meta.md` and `03-plan.md`.
2. `codegraph sync .` — the index may have gone stale since intake.
3. **Check anchors**: `git log --oneline -1`. If HEAD moved since the plan was written, or a planned
   file was changed by someone else, tell the user before proceeding.
4. ```bash
   bash .cursor/task-workflow/scripts/changed-files.sh > .work/<TICKET>/changed-files.txt
   ```
   This is the "before I touched anything" baseline.
5. If the baseline already contains many unrelated files (scratch directories, old untracked files),
   **ask the user which files are in scope**.
6. Open `.work/<TICKET>/journal.md`.

## Step 2 — Execute

Follow the plan in order; tick `[x]` after each step — that is the state that lets you resume.

Before editing each area, call `codegraph_explore` to see callers and blast radius, then climb
the minimum-change ladder. Prefer editing the shared function over adding a new one.

**Journal surprises the moment they happen.** Only where reality differed from expectation:

```markdown
## [<timestamp>] <short title>
Expected: ...
Actual: ...
Evidence: <file:line | command | log>
Plan impact: <none | adjusted step N | needs re-plan>
```

**Drift threshold** — stop, tell the user, update `03-plan.md` before continuing when: a file outside
the plan must change, a new file or abstraction is needed that the plan did not list, more than 2
steps deviate, or an AC turns out to be wrong. Never push on silently.

## Step 3 — Fast loop

Iterate freely. Commands come from the matrix in `00-meta.md`.

```
build       Go: go build ./...          | TS: tsc --noEmit
lint (new)  golangci-lint run --new-from-rev="$(git merge-base origin/<base> HEAD)"
unit        the touched package first, full suite once green
```

Clear this tier **before** touching Sonar.

## Step 4 — Integration tests

Run only **if `00-meta.md` confirms this project has them**. Otherwise record `N/A`.

If they exist but need infrastructure (DB, Redis, containers), check whether it is already up. If
not, **ask the user**; do not start it yourself. Record `SKIPPED (infrastructure not available)`.

## Step 5 — Sonar gate

Details: [sonar-scope.md](../../task-workflow/sonar-scope.md). Run **once, when the code is stable**.

1. Confirm with the user first if Sonar needs to start a container (heavy, ~4GB RAM).
2. Regenerate `changed-files.txt` (it now includes the files you just edited).
3. Scan → list issues → filter:
   ```bash
   <issue-listing command> | bash .cursor/task-workflow/scripts/scope-filter.sh .work/<TICKET>/changed-files.txt
   ```
4. **Scope is file-level**: a file touched on this branch → fix *every* warning in it, including
   pre-existing ones. Files not touched → **report only**, never edit.
5. **Safety valve**: a file with only a few changed lines but more than 10 outstanding issues → stop
   and ask.
6. Re-scan at most once or twice, then stop and report what remains.

If Sonar cannot run (missing token, Docker down, port busy) → record `sonar: SKIPPED (reason)`,
continue, and state that clearly in the final report.

## Step 6 — Report (`04-verify.md` + chat)

No PR, no Jira update. The chat report is the deliverable:

1. **Changes** — per file, line counts, purpose. Note files reused vs created, and net line delta.
2. **AC ↔ test case ↔ result table**.
3. **Verification results** — build/lint/unit/integration/sonar, stating which were `SKIPPED` and why.
   On failure, paste the real output.
4. **Out of scope** — issues found but deliberately left alone, plus extra layers you refused to add.
5. **Suggested commit message and PR description** as copyable text. Do not execute them.

Never report a skipped step as passing.

## Step 7 — Propose submit (do not retain here)

Do **not** write Hindsight memories in this skill. End the report with:

> Code is in. Run `/task-submit <TICKET>` to save a Hindsight summary (who changed what, fixes, lessons — no source, no options).

If the user agrees in the same turn, follow [task-submit](../task-submit/SKILL.md).

Include a short **retro on this skill**: which step was redundant, missing, or misleading.

## Step 8 — Artifact cleanup

1. `mkdir -p ~/.agent-task-archive/<repo-name>/ && cp -R .work/<TICKET> ~/.agent-task-archive/<repo-name>/`
2. **Ask the user** before deleting.
3. Delete **only the files in the `00-meta.md` manifest**, one by one. No `rm -rf`, no `git clean`.
   Anything in `.work/<TICKET>/` not in the manifest stays, and you say so.
4. Confirm `git status` is as clean as before the run, apart from the source files the plan intended
   to change.

`/task-intake` looks in the archive before researching a ticket again.
