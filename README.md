# Git Committer

`committer` helper script packaged via `devenv`.

- Consumable output: `outputs.committer`
- In-shell command: `committer`
- Usage: `committer <repo-path> "commit message" <file-or-glob> [more files/globs...]`
- Example: `committer . $'feat(domain): add selected files\n\n- include docs\n- include test fixture' test.txt "weird name.txt" "dir/*.md"`                    
- Use ANSI-C quoting so backticks are safe and `\n` is decoded
- Works with changed, added, deleted files (renames: specify both paths to detect) 
