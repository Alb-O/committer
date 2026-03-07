#!/usr/bin/env bash
set -euo pipefail

if (($# < 3)); then
  cmd_name="$(basename "$0")"
  echo "Usage: $cmd_name <repo-path> \"commit message\" <file-or-glob> [more files/globs...]"
  exit 2
fi

repo_path=$1
shift
msg=$1
shift

if ! git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: not a git repository: $repo_path" >&2
  exit 2
fi

files=()
add_files=()
for pattern in "$@"; do
  # Normalize shell globs into git pathspec globs so the same selection logic
  # works whether the caller passes a literal file or a pattern.
  pathspec=$pattern
  if [[ "$pattern" == *[\*\?\[]* ]]; then
    pathspec=":(glob)$pattern"
  fi

  # Existing worktree paths still need `git add -A` so content changes, adds,
  # and deletions under the selected path are refreshed in the index first.
  pattern_in_repo=$pattern
  if [[ "$pattern" != /* ]]; then
    pattern_in_repo="$repo_path/$pattern"
  fi
  if [[ -e "$pattern_in_repo" ]]; then
    files+=("$pathspec")
    add_files+=("$pathspec")
    continue
  fi

  # Deleted tracked paths are valid selections too; `git ls-files` lets the
  # caller target them even though the path no longer exists on disk.
  if git -C "$repo_path" ls-files --error-unmatch -- "$pathspec" >/dev/null 2>&1; then
    files+=("$pathspec")
    add_files+=("$pathspec")
    continue
  fi

  # A path can already be staged away by a previous failed commit attempt.
  # Keep it in the commit set, but skip `git add -A` because there is nothing
  # left in the worktree for git to match.
  if git -C "$repo_path" diff --cached --name-only -- "$pathspec" | grep -q .; then
    files+=("$pathspec")
    continue
  fi

  echo "warning: pathspec did not match tracked or staged files: $pattern" >&2
done

if ((${#files[@]} == 0)); then
  echo "No files selected after glob expansion."
  exit 1
fi

# Only restage selections that still resolve in the worktree or index; staged-
# only deletions were already captured above and would make `git add -A` fail.
if ((${#add_files[@]} > 0)); then
  git -C "$repo_path" add -A -- "${add_files[@]}"
fi
git -C "$repo_path" commit --only -m "$msg" -- "${files[@]}"
