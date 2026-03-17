#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: devenv-run [-C repo_root] [--] <command> [args...]

Run a command inside a repo's generated devenv environment without executing
the repo's shellHook / enterShell tasks.
EOF
}

find_poly_local_inputs_bootstrap() {
  local search_dir=$1

  while true; do
    if [[ -x "$search_dir/repos/poly-local-inputs/bootstrap-local-inputs" ]]; then
      printf '%s\n' "$search_dir/repos/poly-local-inputs/bootstrap-local-inputs"
      return 0
    fi

    local parent
    parent=$(dirname "$search_dir")
    if [[ "$parent" == "$search_dir" ]]; then
      return 1
    fi
    search_dir=$parent
  done
}

latest_shell_export() {
  find .devenv -maxdepth 1 -type f -name 'shell-*.sh' -printf '%T@ %p\n' 2>/dev/null |
    sort -nr |
    head -n 1 |
    cut -d' ' -f2-
}

repo_root=$(pwd)

while [[ $# -gt 0 ]]; do
  case "$1" in
    -C)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for -C" >&2
        exit 2
      fi
      repo_root=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 2
fi

cd "$repo_root"
repo_root=$(pwd)

if [[ ! -f devenv.nix || ! -f devenv.yaml ]]; then
  echo "Not a devenv repo root: $repo_root" >&2
  exit 1
fi

if bootstrap_script=$(find_poly_local_inputs_bootstrap "$repo_root"); then
  polyrepo_root=$(dirname "$(dirname "$(dirname "$bootstrap_script")")")
  "$bootstrap_script" "$repo_root" --polyrepo-root "$polyrepo_root" --repo-dirs-path repos
fi

# Reuse the repo's generated shell export if it already exists. This avoids
# entering `devenv shell`, which can run enterShell tasks with side effects.
shell_script=$(latest_shell_export)

if [[ -z "$shell_script" ]]; then
  # `devenv info` is enough to force materialization of `.devenv/` without
  # actually entering the shell.
  devenv --no-tui info >/dev/null
  shell_script=$(latest_shell_export)
fi

if [[ -z "$shell_script" ]]; then
  echo "No generated .devenv shell export found under $repo_root/.devenv." >&2
  echo "Run 'devenv tasks run devenv:files' and try again." >&2
  exit 1
fi

export PS1=""

# The generated shell script contains both plain environment exports and a final
# `eval "${shellHook:-}"`. Stop before that line so we keep the environment but
# skip formatter / hook setup triggered from shellHook / enterShell.
# shellcheck disable=SC1090
source <(awk '/^eval "\$\{shellHook:-\}"$/ { exit } { print }' "$shell_script")

exec "$@"
