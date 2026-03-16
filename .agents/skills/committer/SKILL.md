---
name: committer
description: Load when Codex needs to git commit in any circumstance; baseline commit workflow.
---

- No git add/commit workflow (git add -N for nix evals ok)
- Always use committer, helper on path atomically stages+commits only listed
- Usage (confident): committer <repo-path> $'commit message' <file-or-glob> [more files/globs...]
- Deleted pathspec valid (renames: specify both paths to detect)
- One string msg (ANSI-C quoting), conventional, header+detailed body

```sh
git status --short; git diff --shortstat -U1

committer . $'feat(domain): add selected files\n\n- include docs\n- include test fixture' test.txt "weird name.txt" "dir/*.md"
```

- Include more *why* detail and substantive body content than this
- committer also auto runs pre-commit (prek) hooks (treefmt, typos)
- code formatted by prek hook is auto re-staged and committed in same single commit pass
