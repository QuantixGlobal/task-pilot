---
name: task-pilot
description: Check whether a newer version of the task-pilot skills (task-intake, task-build, task-submit, task-setup) is available for this project, and ask before pulling it in. Use when the user types /task-pilot, asks to check for updates / update the skills / pull latest skills, or says kiểm tra cập nhật / cập nhật skill / pull skill mới. Never installs anything without an explicit yes. Never edits skill content directly — delegates the actual pull to install.sh.
---

# task-pilot — update check

This project's `task-intake` / `task-build` / `task-submit` / `task-setup`
skills were installed by `install.sh` from a source repo. That installer
stamps the version it installed into `<client>/task-workflow/.source`. This
skill's only job: read that stamp, compare it to what the source repo
currently publishes, and ask before pulling anything newer.

```
FORBIDDEN: running the installer without the user saying yes first
FORBIDDEN: editing any skill file directly to "update" it
FORBIDDEN: guessing a version when the network check fails — say so, stop
ALLOWED:   reading .source files, curl of a public VERSION file, running
           install.sh's own update command after explicit confirmation
```

## 1. Find what's installed here

```bash
for f in .claude/task-workflow/.source .cursor/task-workflow/.source; do
  [ -f "$f" ] && { echo "== $f =="; cat "$f"; echo; }
done
```

Neither file exists → task-pilot is not installed in this project. Say so,
point at the install command in this repo's `README.md`
(`curl -fsSL https://raw.githubusercontent.com/<repo>/<ref>/install.sh | sh`),
and stop. Do not install on your own initiative.

## 2. Read the installed version, per client found

Each `.source` has `repo=`, `ref=`, `client=`, `version=`, `installed=`.

An install made before version tracking existed has no `version=` line —
treat that as `version=0.0.0` (always behind, so an update will be offered).

## 3. Check what the source repo currently publishes

For each **distinct** `repo`+`ref` pair among the `.source` files found (a
project with both `.claude/` and `.cursor/` installed from the same repo/ref
only needs one fetch):

```bash
curl -fsSL "https://raw.githubusercontent.com/<repo>/<ref>/VERSION"
```

If this 404s or the network fails: report that the check could not complete
and stop. Do not fall back to any assumption.

A private source repo needs `GITHUB_TOKEN`:
`curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" ...` — ask the user for a
token only if the plain request comes back 401/404 and they confirm the repo
is private.

## 4. Compare

Plain string equality between the installed `version=` and the fetched
`VERSION` content (trimmed). Do not parse or order-compare semver — a version
bump could go either direction and either way the action is identical: ask.

- **Equal for every client found** → report "task-pilot is up to date (vX)."
  per client and stop here. Do not ask anything, do not touch the network
  again, do not run the installer.
- **Different for at least one client** → go to step 5.

## 5. Ask before pulling

Report old → new version, per client where they differ. Then ask a plain
yes/no: update now? If both `.claude/` and `.cursor/` are behind on the same
repo/ref, ask once for both rather than twice.

**No** → leave everything untouched, restate the currently installed
version(s), stop.

**Yes** → run, for each client that needs it, the update command using the
values recorded in its own `.source` (not assumed defaults):

```bash
curl -fsSL "https://raw.githubusercontent.com/<repo>/<ref>/install.sh" \
  | sh -s -- --client <claude|cursor> --ref <ref>
```

This reuses `install.sh`'s own replace-not-merge logic and its guard against
touching anything outside the five paths it owns — this skill does not
reimplement that, it only decides whether to invoke it.

After it runs, read the refreshed `.source` and confirm the new `version=`
matches what step 3 fetched; report success or, if it still doesn't match,
say so rather than declaring success.
