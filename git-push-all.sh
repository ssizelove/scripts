#!/usr/bin/env bash
set -euo pipefail

# git-push-all.sh — safer push + tag helper
# - Keeps your timestamped commit message pattern
# - Adds options:
#     --no-tag                Skip tag creation
#     --tag-if-commit-only    Create tag only if a new commit was made
#     --remote <name>         Use a remote other than 'origin'
#     -m "message"            Commit message (spaces ok)
#     -n / --dry-run          Print actions instead of executing them
#
# Examples:
#   ./git-push-all.sh
#   ./git-push-all.sh -m "Refactor grocery item model"
#   ./git-push-all.sh --tag-if-commit-only
#   ./git-push-all.sh --remote upstream -m "Sync to upstream"

DRY_RUN=0
DO_TAG=1
TAG_IF_COMMIT_ONLY=0
REMOTE="origin"
DESCRIPTION=""

# --- arg parsing ---
print_help() {
  cat <<'EOF'
Usage: git-push-all.sh [options]

Options:
  -m "message"          Commit message (timestamp appended automatically)
  --no-tag              Skip tag creation
  --tag-if-commit-only  Only create a tag if a commit was created
  --remote <name>       Remote name to push to (default: origin)
  -n, --dry-run         Show what would be done, don't do it
  -h, --help            Show this help
EOF
}

while (( "$#" )); do
  case "$1" in
    -m)
      shift
      DESCRIPTION="${1:-}"; shift || true
      ;;
    --no-tag)
      DO_TAG=0; shift
      ;;
    --tag-if-commit-only)
      TAG_IF_COMMIT_ONLY=1; shift
      ;;
    --remote)
      shift
      REMOTE="${1:-origin}"; shift || true
      ;;
    -n|--dry-run)
      DRY_RUN=1; shift
      ;;
    -h|--help)
      print_help; exit 0
      ;;
    *)
      # Treat a lone non-flag as the description for backward compat
      if [[ "${1:-}" != "" && "${1:0:1}" != "-" && -z "$DESCRIPTION" ]]; then
        DESCRIPTION="$1"; shift
      else
        echo "Unknown argument: $1"
        print_help
        exit 1
      fi
      ;;
  esac
done

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '[dry-run] %s\n' "$*"
  else
    eval "$@"
  fi
}

# --- repo root & sanity checks ---
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository."; exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
  echo "Remote '$REMOTE' does not exist."; exit 1
fi

# Guard against unresolved conflicts
if [[ -n "$(git diff --name-only --diff-filter=U)" ]]; then
  echo "There are unresolved merge conflicts. Resolve them before pushing."; exit 1
fi

# Guard against detached HEAD when pushing by branch name
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
  echo "Detached HEAD detected. Check out a branch before running this script."; exit 1
fi

# Timestamp formats (consistent with your original)
HUMAN_TS="$(date '+%Y_%m_%d %I:%M %p')"    # 2025_08_30 11:00 AM
TAG_TS="$(date '+%Y_%m_%d-%I%M%p')"         # 2025_08_30-1100AM

if [[ -n "$DESCRIPTION" ]]; then
  COMMIT_MSG="${DESCRIPTION} (${HUMAN_TS})"
  TAG_MSG="${DESCRIPTION} - ${HUMAN_TS}"
else
  COMMIT_MSG="Updated: ${HUMAN_TS}"
  TAG_MSG="Auto tag: ${HUMAN_TS}"
fi

# Stage all changes
run "git add -A"

# Determine whether we will commit
DID_COMMIT=0
if git diff --cached --quiet; then
  echo "No staged changes to commit."
else
  run "git commit -m \"\$COMMIT_MSG\""
  DID_COMMIT=1
fi

# Ensure upstream exists; if not, set it on first push
HAS_UPSTREAM=0
if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
  HAS_UPSTREAM=1
fi

if [[ $HAS_UPSTREAM -eq 1 ]]; then
  run "git push $REMOTE \"$CURRENT_BRANCH\""
else
  echo "No upstream set for '$CURRENT_BRANCH'. Pushing with -u to '$REMOTE/$CURRENT_BRANCH'."
  run "git push -u $REMOTE \"$CURRENT_BRANCH\""
fi

# Tagging logic
if [[ $DO_TAG -eq 1 ]]; then
  if [[ $TAG_IF_COMMIT_ONLY -eq 1 && $DID_COMMIT -eq 0 ]]; then
    echo "Skipping tag: --tag-if-commit-only set and no new commit was created."
  else
    BASE_TAG="${TAG_TS}"
    TAG_NAME="${BASE_TAG}"
    i=2
    # Avoid collisions both locally and remotely
    while git rev-parse -q --verify "refs/tags/${TAG_NAME}" >/dev/null || git ls-remote --exit-code --tags "$REMOTE" "refs/tags/${TAG_NAME}" >/dev/null 2>&1; do
      TAG_NAME="${BASE_TAG}-${i}"
      ((i++))
    done
    run "git tag -a \"\$TAG_NAME\" -m \"\$TAG_MSG\""
    run "git push \"$REMOTE\" \"\$TAG_NAME\""
    echo "✅ Pushed branch '${CURRENT_BRANCH}' and tag '${TAG_NAME}'"
  fi
else
  echo "✅ Pushed branch '${CURRENT_BRANCH}' (tagging disabled)"
fi
