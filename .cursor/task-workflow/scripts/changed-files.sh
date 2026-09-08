#!/usr/bin/env bash
# List files changed on the current branch: committed vs base + staged + unstaged + untracked.
# Usage: bash changed-files.sh                 -> paths on stdout, "# base=... merge-base=..." on stderr
#        BASE=origin/develop bash changed-files.sh
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

detect_base() {
  if [[ -n "${BASE:-}" ]]; then printf '%s' "$BASE"; return; fi
  local h c
  if h="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"; then
    printf '%s' "$h"; return
  fi
  for c in main master develop dev sit staging; do
    if git rev-parse --verify -q "origin/$c" >/dev/null 2>&1; then printf 'origin/%s' "$c"; return; fi
    if git rev-parse --verify -q "$c" >/dev/null 2>&1; then printf '%s' "$c"; return; fi
  done
  printf 'HEAD'
}

BASE_REF="$(detect_base)"
MB="$(git merge-base "$BASE_REF" HEAD 2>/dev/null || echo HEAD)"

{
  git diff --name-only "$MB" HEAD 2>/dev/null || true          # committed on this branch
  git diff --name-only HEAD 2>/dev/null || true                # unstaged
  git diff --name-only --cached 2>/dev/null || true            # staged
  git ls-files --others --exclude-standard 2>/dev/null || true # untracked
} | sed '/^$/d' | grep -v '^\.work/' | sort -u

echo "# base=$BASE_REF merge-base=$MB" >&2
