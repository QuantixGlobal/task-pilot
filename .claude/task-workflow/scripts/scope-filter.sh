#!/usr/bin/env bash
# Filter a tool's output (sonar issues, lint, ...) down to lines mentioning files changed on
# this branch. Reads the tool output from stdin.
#
# Usage: make sonar-issues | bash scope-filter.sh <changed-files.txt>
#        bash changed-files.sh > /tmp/cf.txt && golangci-lint run ./... | bash scope-filter.sh /tmp/cf.txt
#
# Prints "matched/total" to stderr so the caller knows how much was filtered out.
set -euo pipefail

CF="${1:?usage: scope-filter.sh <changed-files.txt>}"
[[ -s "$CF" ]] || { echo "scope-filter: changed-file list is empty — nothing is in scope." >&2; exit 0; }

TMP_IN="$(mktemp)"; TMP_PAT="$(mktemp)"
trap 'rm -f "$TMP_IN" "$TMP_PAT"' EXIT
cat > "$TMP_IN"

sed '/^$/d' "$CF" > "$TMP_PAT"

TOTAL="$(wc -l < "$TMP_IN" | tr -d ' ')"
grep -F -f "$TMP_PAT" "$TMP_IN" || true
MATCHED="$(grep -c -F -f "$TMP_PAT" "$TMP_IN" || true)"

echo "# scope-filter: ${MATCHED:-0}/${TOTAL} lines in branch scope ($(wc -l < "$TMP_PAT" | tr -d ' ') files)" >&2
