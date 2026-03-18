## devenv-run

Run repo's shell without shellHook or enterShell side effects (doesn't regenerate envionment)
Usage: devenv-run [-C repo_root] [--] <command> [args...]
Example: devenv-run -C repos/nusim/nusim_app cargo build --workspace
