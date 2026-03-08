# Committer

- No git add/commit workflow (git add -N for nix evals ok)
- Always use `committer`, helper on path atomically stages+commits only listed
    - Usage (confident): `committer <repo-path> $'commit message' <file-or-glob> [more files/globs...]`
        - One string msg, conventional, header+detailed body
        - Use ANSI-C quoting `committer . $'feat(domain): add selected files\n\n- include docs\n- include test fixture' test.txt "weird name.txt" "dir/*.md"`
    - Deleted pathspec valid (renames: specify both paths to detect)
