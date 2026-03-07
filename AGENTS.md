# Git Committer

- Don't use typical `git add/commit` workflow (`git add -N` for nix evals ok)
- Always use the `committer` (helper script on path, atomically stages+commits only listed)
    - Usage (confident): `committer <repo-path> $'commit message' <file-or-glob> [more files/globs...]`
        - One string msg, conventional, header and detailed bulleted body
        - Example: `committer . $'feat(domain): add selected files\n\n- include docs\n- include test fixture' test.txt "weird name.txt" "dir/*.md"`
        - ANSI-C quoting so backticks are safe and `\n` is decoded
    - Works with changed, added, deleted files (renames: specify both paths to detect)
