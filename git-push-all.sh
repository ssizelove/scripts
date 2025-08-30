#!/usr/bin/env bash
set -euo pipefail

# Go to repo root if we're inside a subdir
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  echo "Not inside a git repository."
  exit 1
fi
cd "$REPO_ROOT"

# Timestamp formats
HUMAN_TS="$(date '+%Y_%m_%d %I:%M %p')"       # e.g. 2025_08_30 11:00 AM
TAG_TS="$(date '+%Y_%m_%d-%I%M%p')"            # e.g. 2025_08_30-1100AM (no spaces)

# Stage all changes
git add -A

# Commit if there are staged changes
if git diff --cached --quiet; then
  echo "No changes to commit."
else
  git commit -m "Updated: ${HUMAN_TS}"
fi

# Push current branch
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git push origin "$CURRENT_BRANCH"

# Prepare tag name (avoid collisions)
BASE_TAG="${TAG_TS}"
TAG_NAME="${BASE_TAG}"
i=2
while git rev-parse -q --verify "refs/tags/${TAG_NAME}" >/dev/null; do
  TAG_NAME="${BASE_TAG}-${i}"
  ((i++))
done

# Create annotated tag pointing to HEAD
git tag -a "${TAG_NAME}" -m "Auto tag: ${HUMAN_TS}"

# Push just-created tag
git push origin "${TAG_NAME}"

echo "✅ Pushed branch '${CURRENT_BRANCH}' and tag '${TAG_NAME}'"
