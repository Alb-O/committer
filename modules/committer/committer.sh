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

repo_root=$(git -C "$repo_path" rev-parse --show-toplevel)
pre_commit_config="$repo_root/.pre-commit-config.yaml"

files=()
initial_add_files=()
initial_delete_files=()
retry_add_files=()
for pattern in "$@"; do
  # Normalize shell globs into git pathspec globs so the same selection logic
  # works whether the caller passes a literal file or a pattern.
  pathspec=$pattern
  pattern_is_glob=false
  if [[ "$pattern" == *[\*\?\[]* ]]; then
    pattern_is_glob=true
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
    initial_add_files+=("$pathspec")
    retry_add_files+=("$pathspec")
    continue
  fi

  # Quoted globs should target new untracked files. Preserve the
  # glob pathspec so `git add -A` can stage them.
  if git -C "$repo_path" ls-files --others --exclude-standard -- "$pathspec" | grep -q .; then
    files+=("$pathspec")
    initial_add_files+=("$pathspec")
    retry_add_files+=("$pathspec")
    continue
  fi

  # Globs that match tracked paths should stay on the `git add -A` path. A
  # literal `-e` check cannot see through a glob, so without this branch they
  # get misclassified as deletions and staged through `git rm --cached`.
  if $pattern_is_glob && git -C "$repo_path" ls-files --cached -- "$pathspec" | grep -q .; then
    files+=("$pathspec")
    initial_add_files+=("$pathspec")
    retry_add_files+=("$pathspec")
    continue
  fi

  # Deleted tracked paths are valid selections too; `git ls-files` lets the
  # caller target them even though the path no longer exists on disk.
  #
  # Stage them once up front via `git rm --cached`, but do not include them in
  # later retry restages. `git add -A` rejects ignored pathspecs even when the
  # tracked file has been deleted, which breaks selected deletions once a path
  # has become ignored.
  if git -C "$repo_path" ls-files --error-unmatch -- "$pathspec" >/dev/null 2>&1; then
    files+=("$pathspec")
    initial_delete_files+=("$pathspec")
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

# Only restage selections that still resolve in the worktree or the first add
# pass. Staged-only deletions were already captured above and would make repeat
# `git add -A` calls fail.
if ((${#initial_add_files[@]} > 0)); then
  git -C "$repo_path" add -A -- "${initial_add_files[@]}"
fi

if ((${#initial_delete_files[@]} > 0)); then
  git -C "$repo_path" rm -q -r --cached --ignore-unmatch -- "${initial_delete_files[@]}"
fi

hook_files=()
while IFS= read -r path; do
  [[ -n "$path" ]] && hook_files+=("$path")
done < <(
  git -C "$repo_path" diff --cached --name-only --diff-filter=ACMRTUXB -- "${files[@]}"
)

run_pre_commit_hooks() {
  if [[ ! -f "$pre_commit_config" ]]; then
    return 0
  fi

  if command -v prek >/dev/null 2>&1; then
    (
      cd "$repo_path"
      prek run --color always --stage pre-commit --files "${hook_files[@]}"
    )
  elif command -v pre-commit >/dev/null 2>&1; then
    (
      cd "$repo_path"
      pre-commit run --hook-stage pre-commit --files "${hook_files[@]}"
    )
  else
    echo $'error: neither `prek` nor `pre-commit` is available on PATH' >&2
    exit 1
  fi
}

snapshot_selected_state() {
  local prefix=$1
  git -C "$repo_path" diff --binary -- "${files[@]}" >"${prefix}.worktree"
  git -C "$repo_path" diff --binary --cached -- "${files[@]}" >"${prefix}.index"
}

# `git commit --only` runs hooks against a locked temporary next-index, which
# breaks fixup-style hooks that restage files (for example treefmt wrappers that
# call `git add`). Run pre-commit eagerly against the selected staged files, let
# those hooks update the real index, then disable hook re-entry for the actual
# commit step.
if ((${#hook_files[@]} > 0)); then
  hook_tmpdir=$(mktemp -d)
  trap 'rm -rf "$hook_tmpdir"' EXIT

  attempt=0
  max_attempts=5
  while true; do
    attempt=$((attempt + 1))
    hook_log="$hook_tmpdir/hook-${attempt}.log"
    snapshot_selected_state "$hook_tmpdir/before"

    set +e
    run_pre_commit_hooks >"$hook_log" 2>&1
    rc=$?
    set -e

    if ((rc == 0)); then
      cat "$hook_log"
      break
    fi

    if ((${#retry_add_files[@]} > 0)); then
      git -C "$repo_path" add -A -- "${retry_add_files[@]}"
    fi

    snapshot_selected_state "$hook_tmpdir/after"
    if cmp -s "$hook_tmpdir/before.worktree" "$hook_tmpdir/after.worktree" &&
      cmp -s "$hook_tmpdir/before.index" "$hook_tmpdir/after.index"; then
      cat "$hook_log" >&2
      exit "$rc"
    fi

    if ((attempt >= max_attempts)); then
      cat "$hook_log" >&2
      echo "error: pre-commit hooks kept modifying selected files after ${max_attempts} attempts" >&2
      exit "$rc"
    fi
  done
fi

git -C "$repo_path" commit --only --no-verify -m "$msg" -- "${files[@]}"
