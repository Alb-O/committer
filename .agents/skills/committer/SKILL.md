---
name: committer
description: Load when Codex needs to git commit in any circumstance; baseline commit workflow.
---

- No git add/commit workflow (git add -N for nix evals ok)
- Always use committer, helper on path atomically stages+commits only listed
- Usage (confident): committer <repo-path> $'commit message' <file-or-glob> [more files/globs...]
- These all commit cleanly in one pass:
	- Fully deleted tracked globs
	- Renames (specify both paths to detect)
	- Mixed glob with one modified file and one deleted file
	- Pure untracked glob

```sh
git status --short; git diff --shortstat -U1

committer . $'feat(domain): add selected files\n\n- include docs\n- include test fixture' test.txt "weird name.txt" "dir/*.md"
```

- Style: One string msg (ANSI-C quoting), conventional, header+detailed body
- Include more *why* detail and substantive body content
- committer also auto runs pre-commit (prek) hooks (treefmt, typos)
- code formatted by prek hook is auto re-staged and committed in same single commit pass
