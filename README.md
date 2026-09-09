# Task Pilot - Agentic Skills

<p align="center">
  <b>🇬🇧 English</b> ・ <a href="README.vi.md">🇻🇳 Tiếng Việt</a>
</p>

A ticket-to-merge workflow for coding agents — **Claude Code** and **Cursor**.

Point it at a Jira ticket, or just describe what you want in plain text (Vietnamese
or English), and it takes you through research → an approved plan → implementation
→ verification → a distilled memory of what shipped. Each step is its own skill, so
you review and approve between them instead of one long agent run.

```
/tp-setup   →   /tp-intake   →   /tp-build   →   /tp-submit
   once            per ticket      after approval    after it's verified
```

It also wires up the MCP servers the workflow leans on — Jira, Outline, local
SonarQube, Hindsight memory, CodeGraph — and can check itself for updates.

## Install

Run from the root of the project you want the skills in.

**Claude Code:**

```bash
curl -fsSL https://raw.githubusercontent.com/QuantixGlobal/task-pilot/main/install.sh | sh -s -- --client claude
```

**Cursor:**

```bash
curl -fsSL https://raw.githubusercontent.com/QuantixGlobal/task-pilot/main/install.sh | sh -s -- --client cursor
```

**Not sure, or want both?** Leave `--client` off — the installer looks at the
project and figures it out:

```bash
curl -fsSL https://raw.githubusercontent.com/QuantixGlobal/task-pilot/main/install.sh | sh
```


| Project has     | Installs into                                      |
| --------------- | -------------------------------------------------- |
| `.claude/` only | `.claude/`                                         |
| `.cursor/` only | `.cursor/`                                         |
| both            | both                                               |
| neither         | asks you on the terminal, creates the one you pick |


Restart Claude Code (or reload Cursor) afterwards — the five slash commands
below are then available.

## The workflow, in order


| Step | Skill                          | When                                                                                   |
| ---- | ------------------------------ | -------------------------------------------------------------------------------------- |
| 0    | [`/tp-setup`](#tp-setup)   | Once per machine/repo, before the first ticket. Re-run only to add a tool you skipped. |
| 1    | [`/tp-intake`](#tp-intake) | Start of every ticket. Give it a Jira key/link, or describe the task directly.         |
| 2    | [`/tp-build`](#tp-build)   | After you approve the plan `/tp-intake` produced.                                    |
| 3    | [`/tp-submit`](#tp-submit) | After `/tp-build` verifies clean and you're happy with the result.                   |
| —    | [`/tp-pilot`](#tp-pilot)   | Any time, unrelated to any ticket — checks for a newer version of these skills.        |


`/tp-setup` and `/tp-pilot` sit outside the per-ticket loop. The other
three are meant to run in that order, one ticket at a time — `/tp-build`
refuses to start without a plan from `/tp-intake`, and `/tp-submit` looks
for `/tp-build`'s output.

### `/tp-setup`

Installs and wires: Jira MCP, Outline MCP, local SonarQube (Docker), Hindsight
memory, CodeGraph. Run once; asks which tool(s) if you don't name one.
**You** create API keys / complete OAuth — it never invents credentials or
commits tokens.

```
/tp-setup                 → asks which tool to configure
/tp-setup jira outline     → just those two
/tp-setup all               → everything
```

### `/tp-intake`

Research phase — **writes no code**. Give it a ticket key (`ABC-123`), a Jira
URL, or a plain request in any language. It reads the ticket (comments,
attachments, linked issues) or takes your text as the spec, checks git
history and any configured Sonar/CodeGraph/Hindsight context, and ends with a
plan you have to approve before anything else happens.

Before any of that, it runs [`/tp-pilot`](#tp-pilot)'s version check —
silent if you're current, otherwise it asks before pulling in an update, then
continues into the research above either way.

```
/tp-intake ABC-123
/tp-intake add session invalidation in updating user's profile API
```

### `/tp-build`

Executes the plan you just approved: writes the code, runs build/lint/unit
and integration tests, runs Sonar scoped to only the files this branch
touched, and reports against the ticket's acceptance criteria. Never commits,
pushes, opens a PR, or writes to Jira — that stays a manual step, on purpose.

```
/tp-build
```

### `/tp-submit`

Distills the finished ticket into Hindsight memory — **outcomes only**: which
function/file changed, what's true now, who did it. Never stores raw code,
diffs, or the plan's rejected options. Recalls first and skips anything
already recorded.

```
/tp-submit
```

### `/tp-pilot`

Not part of the ticket loop — run it whenever, to check whether this repo has
published newer skills than the ones installed here. Skips silently if you're
already current; otherwise tells you old → new and asks before pulling
anything in.

```
/tp-pilot
```

## Updating

Same as checking: run `/tp-pilot`. It compares the version recorded at
install time against this repo's [`VERSION`](VERSION) file and only updates
after you say yes.

Prefer to skip the check and just force a reinstall? Run the same install
command again — it does not ask, and always overwrites with the latest.

## Install script reference


| Option                        | Effect                                                 |
| ----------------------------- | ------------------------------------------------------ |
| `--client claude|cursor|both` | Skip auto-detection and say which.                     |
| `--dir <path>`                | Project to install into. Default: current directory.   |
| `--ref <ref>`                 | Branch, tag, or commit to install. Default: `main`.    |
| `--dry-run`                   | Print what would change, write nothing.                |
| `--uninstall`                 | Remove what the installer put there, and nothing else. |
| `--from <path>`               | Install from a local checkout instead of downloading.  |
| `GITHUB_TOKEN`                | Sent as a Bearer token, if this repo is private.       |


### What it touches

Exactly six paths per client, and nothing else:

```
<client>/skills/tp-intake
<client>/skills/tp-build
<client>/skills/tp-submit
<client>/skills/tp-setup
<client>/skills/tp-pilot
<client>/task-workflow
```

Your `settings.json`, `mcp.json`, and **any other skill in the same
`skills/` directory are never read, moved, or deleted** — a guard in the
installer refuses to touch a path outside this list, and `--uninstall` goes
through the same guard.

These six are *replaced* on every install, not merged, so a file dropped
upstream doesn't linger after an update — but it also means a local edit
inside them is overwritten. Run `--dry-run` first if you've hand-edited
anything here.

`<client>/task-workflow/.source` records the `repo`, `ref`, and `version`
installed; `/tp-pilot` reads it. An install from before version tracking
existed (no `version=` line) is always treated as behind.

## Developing

`.claude/` is the source of truth; edit skills there only. The Cursor copy is
generated at install time by rewriting the `.claude/task-workflow/` path
prefix to `.cursor/`.

Test a change without pushing:

```bash
./install.sh --from . --dir /tmp/scratch-repo --client both --dry-run
```

Bump [`VERSION`](VERSION) whenever a skill's content changes — it's a plain
string compare against the installed stamp, not semver ordering, so any
change to the file (not just an increment) is enough for `/tp-pilot` to
offer an update.