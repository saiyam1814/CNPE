#!/bin/bash
# Sync the cnpe/ course from this repo (source of truth) into the
# katacoda-scenarios repo that Killercoda actually serves, then push.
#
# Usage:
#   ./sync-to-killercoda.sh [path-to-katacoda-scenarios] [--dry-run]
#
# If no path is given, uses ~/git/katacoda-scenarios (cloning it if missing).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TARGET_REPO="${1:-$HOME/git/katacoda-scenarios}"
DRY_RUN=0
for a in "$@"; do [ "$a" = "--dry-run" ] && DRY_RUN=1; done
[ "$TARGET_REPO" = "--dry-run" ] && TARGET_REPO="$HOME/git/katacoda-scenarios"

# --- 0. lint the course before shipping anything --------------------------------
echo "==> linting the course"
python3 "$HERE/testing/lint-course.py"

# --- 1. make sure the target repo exists and is the right one -------------------
if [ ! -d "$TARGET_REPO/.git" ]; then
  echo "==> cloning katacoda-scenarios into $TARGET_REPO"
  git clone https://github.com/saiyam1814/katacoda-scenarios "$TARGET_REPO"
fi

REMOTE=$(git -C "$TARGET_REPO" remote get-url origin)
case "$REMOTE" in
  *katacoda-scenarios*) ;;
  *) echo "ERROR: $TARGET_REPO origin is '$REMOTE', not katacoda-scenarios. Aborting."; exit 1 ;;
esac

# never ship a root structure.json into the profile repo - it would hide
# every other scenario on the Killercoda profile
if [ -f "$TARGET_REPO/structure.json" ]; then
  echo "ERROR: $TARGET_REPO has a root structure.json - refusing to touch this repo."
  exit 1
fi

echo "==> updating $TARGET_REPO from origin/main"
git -C "$TARGET_REPO" pull --ff-only origin main

# --- 2. sync ---------------------------------------------------------------------
if [ "$DRY_RUN" = "1" ]; then
  echo "==> DRY RUN - would apply:"
  rsync -a --delete --dry-run --itemize-changes "$HERE/cnpe/" "$TARGET_REPO/cnpe/" | sed 's/^/    /'
  exit 0
fi

rsync -a --delete "$HERE/cnpe/" "$TARGET_REPO/cnpe/"

# --- 3. commit + push only when something changed --------------------------------
if git -C "$TARGET_REPO" status --porcelain -- cnpe | grep -q .; then
  SRC_SHA=$(git -C "$HERE" rev-parse --short HEAD)
  git -C "$TARGET_REPO" add cnpe
  git -C "$TARGET_REPO" commit -m "Sync CNPE course from saiyam1814/CNPE@${SRC_SHA}"
  git -C "$TARGET_REPO" push origin main
  echo "==> pushed. Killercoda's webhook updates the live course within a minute or two."
else
  echo "==> already in sync - nothing to push."
fi
