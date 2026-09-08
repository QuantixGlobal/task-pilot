# Sonar — running it at the right scope

## Why this file exists

By default Sonar returns **the entire project's technical debt**, not the part you just changed.
Running it raw and telling an agent to "fix the warnings" is a recipe for scope explosion: a diff of
thousands of lines, code nobody asked you to touch, and a change nobody can review.

## Agreed scope: FILE level

- A file **touched on the current branch** → fix *every* issue in it, including pre-existing ones.
- A file **not touched** → list it under "out of scope" in the report. Do not edit it.

Example: Sonar reports warnings in 10 files, the branch changed 1 of those 10 → fix only that one.

**Safety valve:** a file with only a few changed lines but more than 10 outstanding issues → stop and
ask. Fixing them all turns a small task into a disguised refactor, and the reviewer can no longer
tell which changes belong to the ticket.

## Getting the scope

```bash
bash .cursor/task-workflow/scripts/changed-files.sh > .work/<TICKET>/changed-files.txt
```

It unions four sources: committed vs merge-base, staged, unstaged, untracked. `git diff HEAD` alone
is not enough — a freshly branched task often has no commits at all, with everything in the working tree.

The script auto-detects the base ref (`origin/HEAD` → main/master/develop/dev/sit/staging) and prints
its choice on stderr. **Read that line and confirm it is right** — a wrong base means a wrong scope.
Override with `BASE=origin/develop bash changed-files.sh`.

## Filtering

```bash
<project's issue-listing command> | bash .cursor/task-workflow/scripts/scope-filter.sh .work/<TICKET>/changed-files.txt
```

The script prints `N/M lines in branch scope` on stderr — use that number when telling the user how
much was filtered out.

## Known pitfalls

**Community Edition has no branch/PR analysis.** A local scan is a mainline view, so the gate's
`new_*` metrics are not trustworthy locally. That is precisely why scope must be filtered by file
rather than trusting Sonar's notion of "new code".

**The `check` command usually fails on the quality gate only, not on individual issues.** An issue in
the file you just edited can still leave the gate PASSING. Do not rely on the exit code — list the
issues and filter them yourself.

**Scanning is expensive** — Docker, several GB of RAM, a fixed port, and minutes per run. It must not
sit inside a fix loop. Run it when the code is stable, and re-scan at most once or twice.

**It needs a token/secret** (usually in `.env`). Missing → `SKIPPED`, which is not a code defect.

**Starting the Sonar stack is a heavy action** — ask the user first, never `docker compose up` on your own.

## golangci-lint: use `--new-from-rev`

At the lint tier (free and fast) there is a built-in way to see only new issues:

```bash
golangci-lint run --new-from-rev="$(git merge-base origin/<base> HEAD)"
```

Use this during the fast loop; save the full `run ./...` for the final check.

## What goes in the report

| File | Issues before | Fixed | Remaining | Why remaining |
|---|---|---|---|---|

Plus one line: how many **out-of-scope** issues were found and deliberately left alone.
