# task-pilot

Ticket-to-merge workflow skills for **Claude Code** and **Cursor**:


| Skill          | Description                                                                                                                    |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `/task-intake` | Research a Jira ticket or a free-form request, produce a plan you approve. No code written.                                    |
| `/task-build`  | Execute the approved plan, verify it (build, lint, tests, Sonar scoped to the branch), report against the acceptance criteria. |
| `/task-submit` | Distil the finished run into Hindsight memory — outcomes only, no raw code.                                                    |
| `/task-setup`  | Wire up Jira MCP, Outline MCP, local SonarQube, Hindsight, and CodeGraph.                                                      |
| `/task-pilot`  | Check whether a newer version of these skills is published, and ask before pulling it in.                                      |


None of them commit, push, open a PR, or write to Jira.

## Install into a project

From the root of the repo you want the skills in:

```bash
curl -fsSL https://raw.githubusercontent.com/QuantixGlobal/task-pilot/main/install.sh | sh
```

Restart Claude Code (or reload Cursor) and the five slash commands are there.

**Updating**: run `/task-pilot` in a session — it checks whether the source
repo has published a newer version, tells you old → new, and only pulls it in
if you say yes. Running `install.sh` by hand again also works and does not ask
(see [What it touches](#what-it-touches)).

### Which client it installs for

With no `--client`, the installer looks at the project and decides:


| Project has     | Installs into                          |
| --------------- | -------------------------------------- |
| `.claude/` only | `.claude/`                             |
| `.cursor/` only | `.cursor/`                             |
| both            | both                                   |
| neither         | asks you, and creates the one you pick |


The question is asked on the terminal, so it works through `curl … \| sh`. In CI
or any other place with no terminal, pass `--client` instead:

```bash
curl -fsSL https://raw.githubusercontent.com/QuantixGlobal/task-pilot/main/install.sh | sh -s -- --client both
```



### Options


|                               |                                                        |
| ----------------------------- | ------------------------------------------------------ |
| `--client claude|cursor|both` | Skip detection and say which.                          |
| `--dir <path>`                | Project to install into. Default: current directory.   |
| `--ref <ref>`                 | Branch, tag, or commit to install. Default: `main`.    |
| `--dry-run`                   | Print what would change, write nothing.                |
| `--uninstall`                 | Remove what the installer put there, and nothing else. |
| `--from <path>`               | Install from a local checkout instead of downloading.  |
| `GITHUB_TOKEN`                | Sent as a Bearer token, if this repo is private.       |




### What it touches

Exactly six directories per client, and nothing else:

```
<client>/skills/task-intake
<client>/skills/task-build
<client>/skills/task-submit
<client>/skills/task-setup
<client>/skills/task-pilot
<client>/task-workflow
```

Your `settings.json`, `mcp.json`, and **your own skills in the same** `skills/`
**directory are never read, moved, or deleted** — a guard in the installer refuses
to remove any path outside that list, and `--uninstall` goes through the same
guard.

Those five are *replaced* rather than merged on an update, so a file dropped
upstream does not linger. Anything you edited inside them is overwritten — use
`--dry-run` first if you have local changes there.

`<client>/task-workflow/.source` records which repo, ref, and **version** is
installed — `/task-pilot` reads this file and compares it against this repo's
`[VERSION](VERSION)` file to decide whether an update exists. An install made
before version tracking existed (no `version=` line in `.source`) is always
treated as behind.

## Developing

`.claude/` is the source of truth. The Cursor copy is generated at install time
by rewriting the `.claude/task-workflow/` path prefix to `.cursor/`, so edit the
skills in one place only.

Test a change without pushing:

```bash
./install.sh --from . --dir /tmp/scratch-repo --client both --dry-run
```

Bump `[VERSION](VERSION)` whenever a skill's content changes — that's the only
signal `/task-pilot` has to offer an update. It is a plain string compare, not
semver ordering, so any change of the file (not just an increment) counts as
"different."