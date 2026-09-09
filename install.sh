#!/bin/sh
# task-pilot — install the tp-intake / tp-build / tp-submit / tp-setup /
# tp-pilot skills into the current project, for Claude Code and/or Cursor.
#
#   curl -fsSL https://raw.githubusercontent.com/QuantixGlobal/task-pilot/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/QuantixGlobal/task-pilot/main/install.sh | sh -s -- --client both
#
# Only the paths this installer owns are touched:
#   <client>/skills/tp-{intake,build,submit,setup,pilot}
#   <client>/task-workflow
# Your settings.json, other skills, and everything else are left alone.

set -eu

REPO="${TASK_PILOT_REPO:-QuantixGlobal/task-pilot}"
REF="${TASK_PILOT_REF:-main}"

# Skills whose own content refers to "<this client>/task-workflow/..." for
# their own scripts, so that prefix gets rewritten for a Cursor install.
REWRITE_SKILLS="tp-intake tp-build tp-submit tp-setup"

# tp-pilot is deliberately excluded from REWRITE_SKILLS: it reads BOTH
# .claude/task-workflow/.source and .cursor/task-workflow/.source itself, on
# purpose, regardless of which client it was installed under -- a blind
# rewrite would collapse that to checking one path twice.
SKILLS="$REWRITE_SKILLS tp-pilot"

CLIENT=""
TARGET="."
FROM=""
DRY_RUN=0
UNINSTALL=0

usage() {
	cat <<'EOF'
task-pilot installer

Usage:
  install.sh [options]

Options:
  --client <claude|cursor|both>  Which client to install for. Detected when
                                 omitted: .claude/ -> claude, .cursor/ ->
                                 cursor, both present -> both, neither -> ask.
  --dir <path>                   Project to install into. Default: current dir.
  --ref <ref>                    Branch, tag, or commit to install. Default: main.
  --from <path>                  Install from a local checkout instead of
                                 downloading (for testing this script).
  --dry-run                      Print what would change, touch nothing.
  --uninstall                    Remove the installed skills and task-workflow.
  -h, --help                     This message.

Environment:
  TASK_PILOT_REPO   owner/repo to fetch from (default QuantixGlobal/task-pilot)
  TASK_PILOT_REF    same as --ref
  GITHUB_TOKEN      sent as a Bearer token, for a private repo

Examples:
  install.sh --client both
  install.sh --client cursor --dir ~/work/other-repo
  install.sh --ref v1.2.0 --dry-run
EOF
}

die() {
	echo "task-pilot: $*" >&2
	exit 1
}

while [ $# -gt 0 ]; do
	case "$1" in
	--client)
		[ $# -ge 2 ] || die "--client needs a value"
		CLIENT="$2"
		shift 2
		;;
	--client=*)
		CLIENT="${1#*=}"
		shift
		;;
	--dir)
		[ $# -ge 2 ] || die "--dir needs a value"
		TARGET="$2"
		shift 2
		;;
	--dir=*)
		TARGET="${1#*=}"
		shift
		;;
	--ref)
		[ $# -ge 2 ] || die "--ref needs a value"
		REF="$2"
		shift 2
		;;
	--ref=*)
		REF="${1#*=}"
		shift
		;;
	--from)
		[ $# -ge 2 ] || die "--from needs a value"
		FROM="$2"
		shift 2
		;;
	--from=*)
		FROM="${1#*=}"
		shift
		;;
	--dry-run) DRY_RUN=1; shift ;;
	--uninstall) UNINSTALL=1; shift ;;
	-h | --help)
		usage
		exit 0
		;;
	*) die "unknown option: $1 (try --help)" ;;
	esac
done

[ -n "$TARGET" ] || die "--dir cannot be empty"
[ -d "$TARGET" ] || die "no such directory: $TARGET"

# --- which client ------------------------------------------------------------

# Nothing to detect: ask. Under `curl | sh` stdin is the script itself, so the
# question has to go to the terminal directly.
ask_client() {
	# `test -r /dev/tty` is not enough: the device node exists even with no
	# controlling terminal, and only the open fails. So try to open it.
	if ! { : >/dev/tty; } 2>/dev/null; then
		die "no .claude/ or .cursor/ in $TARGET, and no terminal to ask on. Re-run with --client claude|cursor|both"
	fi
	{
		echo ""
		echo "No .claude/ or .cursor/ found in $TARGET."
		echo "Install task-pilot for which client?"
		echo "  1) Claude Code  - creates .claude/"
		echo "  2) Cursor       - creates .cursor/"
		echo "  3) both"
		printf "Choice [1]: "
	} >/dev/tty
	read -r answer </dev/tty || answer=""
	echo "" >/dev/tty
	case "$answer" in
	"" | 1 | claude | Claude) echo claude ;;
	2 | cursor | Cursor) echo cursor ;;
	3 | both | Both) echo both ;;
	*) die "unrecognized choice: $answer" ;;
	esac
}

if [ -z "$CLIENT" ]; then
	has_claude=0
	has_cursor=0
	if [ -d "$TARGET/.claude" ]; then has_claude=1; fi
	if [ -d "$TARGET/.cursor" ]; then has_cursor=1; fi

	if [ "$has_claude" = 1 ] && [ "$has_cursor" = 1 ]; then
		CLIENT=both
		echo "task-pilot: found .claude/ and .cursor/ - installing into both"
	elif [ "$has_claude" = 1 ]; then
		CLIENT=claude
		echo "task-pilot: found .claude/ - installing for Claude Code"
	elif [ "$has_cursor" = 1 ]; then
		CLIENT=cursor
		echo "task-pilot: found .cursor/ - installing for Cursor"
	else
		CLIENT="$(ask_client)"
	fi
fi

case "$CLIENT" in
claude) CLIENT_DIRS=".claude" ;;
cursor) CLIENT_DIRS=".cursor" ;;
both) CLIENT_DIRS=".claude .cursor" ;;
*) die "--client must be claude, cursor, or both (got: $CLIENT)" ;;
esac

# --- paths we own ------------------------------------------------------------

# Hard stop against ever deleting something that is not ours. Every removal in
# this script goes through here first.
assert_managed() {
	case "${1##*/}" in
	tp-intake | tp-build | tp-submit | tp-setup | tp-pilot | task-workflow) ;;
	*) die "refusing to remove a path task-pilot does not own: $1" ;;
	esac
	case "$1" in
	*/.claude/skills/* | */.cursor/skills/* | */.claude/task-workflow | */.cursor/task-workflow) ;;
	*) die "refusing to remove a path outside a client dir: $1" ;;
	esac
}

remove_managed() {
	assert_managed "$1"
	[ -d "$1" ] || return 0
	if [ "$DRY_RUN" = 1 ]; then
		echo "  would remove  $1"
		return 0
	fi
	rm -rf "$1"
	echo "  removed  $1"
}

# --- uninstall ---------------------------------------------------------------

if [ "$UNINSTALL" = 1 ]; then
	for dir in $CLIENT_DIRS; do
		for s in $SKILLS; do
			remove_managed "$TARGET/$dir/skills/$s"
		done
		remove_managed "$TARGET/$dir/task-workflow"
		# rmdir only succeeds on an empty dir, so settings and any other
		# skills keep the client dir alive
		rmdir "$TARGET/$dir/skills" 2>/dev/null || true
		rmdir "$TARGET/$dir" 2>/dev/null || true
	done
	echo "task-pilot: uninstalled"
	exit 0
fi

# --- get the payload ---------------------------------------------------------

if [ -n "$FROM" ]; then
	[ -d "$FROM/.claude/skills" ] || die "--from $FROM does not look like a task-pilot checkout"
	SRC="$FROM"
	ORIGIN="local:$FROM"
else
	command -v curl >/dev/null 2>&1 || die "curl is required"
	command -v tar >/dev/null 2>&1 || die "tar is required"

	TMP="$(mktemp -d)"
	trap 'rm -rf "$TMP"' EXIT INT TERM HUP

	url="https://codeload.github.com/$REPO/tar.gz/$REF"
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$url" -o "$TMP/src.tgz" ||
			die "download failed: $url (check --ref, and GITHUB_TOKEN if the repo is private)"
	else
		curl -fsSL "$url" -o "$TMP/src.tgz" ||
			die "download failed: $url (check --ref, or set GITHUB_TOKEN if the repo is private)"
	fi
	tar -xzf "$TMP/src.tgz" -C "$TMP" || die "could not unpack the archive"

	SRC=""
	for d in "$TMP"/*/; do
		[ -d "$d" ] || continue
		SRC="${d%/}"
		break
	done
	[ -n "$SRC" ] || die "unexpected archive layout"
	ORIGIN="$REPO@$REF"
fi

PAYLOAD="$SRC/.claude"
[ -d "$PAYLOAD/task-workflow" ] || die "payload is missing .claude/task-workflow"

VERSION_STR="$(cat "$SRC/VERSION" 2>/dev/null | tr -d '[:space:]')"
[ -n "$VERSION_STR" ] || VERSION_STR="unknown"

# --- copy --------------------------------------------------------------------

# Replace one directory we own -- and only ever that one directory. Sibling
# skills in the same skills/ dir are never read, moved, or removed.
#
# Replace rather than merge, so a file dropped upstream does not linger in an
# updated install.
replace_dir() {
	from="$1"
	to="$2"
	[ -d "$from" ] || die "payload is missing $from"
	assert_managed "$to"

	if [ "$DRY_RUN" = 1 ]; then
		if [ -d "$to" ]; then echo "  would replace  $to"; else echo "  would add      $to"; fi
		return
	fi

	if [ -d "$to" ]; then verb="replaced"; else verb="added   "; fi
	rm -rf "$to"
	mkdir -p "$(dirname "$to")"
	cp -R "$from" "$to"
	echo "  $verb $to"
}

for dir in $CLIENT_DIRS; do
	dest="$TARGET/$dir"
	echo "task-pilot: installing into $dest (from $ORIGIN)"

	for s in $SKILLS; do
		replace_dir "$PAYLOAD/skills/$s" "$dest/skills/$s"
	done
	replace_dir "$PAYLOAD/task-workflow" "$dest/task-workflow"

	[ "$DRY_RUN" = 1 ] && continue

	# The skills are authored against .claude/task-workflow/. Cursor reads the
	# same files from .cursor/, so rewrite the prefix there.
	#
	# Scoped to the directories we just wrote -- never `find $dest/skills`,
	# which would sed straight through the user's own skills.
	if [ "$dir" != ".claude" ]; then
		ours="$dest/task-workflow"
		for s in $REWRITE_SKILLS; do
			ours="$ours $dest/skills/$s"
		done
		# shellcheck disable=SC2086  # $ours is a list of paths we built
		find $ours -name '*.md' -type f -exec \
			sed -i.taskpilotbak "s|\.claude/task-workflow/|$dir/task-workflow/|g" {} +
		# shellcheck disable=SC2086
		find $ours -name '*.taskpilotbak' -type f -delete
	fi

	chmod +x "$dest/task-workflow/scripts/"*.sh 2>/dev/null || true

	cat >"$dest/task-workflow/.source" <<EOF
repo=$REPO
ref=$REF
client=$dir
version=$VERSION_STR
installed=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
EOF
done

if [ "$DRY_RUN" = 1 ]; then
	echo "task-pilot: dry run, nothing written"
	exit 0
fi

echo
echo "task-pilot: done. Available as /tp-intake, /tp-build, /tp-submit, /tp-setup, /tp-pilot"
echo "            Only the paths listed above were touched - your settings and"
echo "            any other skills are untouched."
echo "            Restart Claude Code, or reload Cursor, to pick them up."
