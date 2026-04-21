# 05-tools

CLI productivity tools that don't fit under a language or editor.

## Scope

- `01-fzf.sh` — fzf from git (apt version is too old for the OMZ fzf
  plugin).
- `02-github-cli.sh` — `gh` via the official GitHub apt repo.
- `03-pay-respects.sh` — `thefuck` replacement (`thefuck` is broken on
  Python 3.12+); cargo install. Also cleans up legacy `pipx` thefuck
  install if present.
- `04-cli-extensions.sh` — the bundle that was `install-cli-extensions.sh`
  at repo root: atuin, tealdeer, yq v4, glab, watchexec, rga,
  git-branchless, tokscale. Uses the apt/cargo/npm fallback pattern
  (official binaries first; cargo build for rust tools; npm for
  tokscale).
- `05-taskwarrior.sh` — Taskwarrior 3.x built from source (apt only
  ships 2.x). Also symlinks `.taskrc` manually (NOT via stow — the
  stow `--ignore` list skips `.taskrc`) and patches the home path in
  it.

## Ordering

- Fully reorderable — no intra-bucket edges. All siblings.

## Needs from upstream buckets

- `01-system` — apt packages, pipx path setup.
- `02-languages/07-rust` — cargo for `03-pay-respects`, the cargo
  fallbacks inside `04-cli-extensions` (rga, watchexec, git-branchless),
  and the TaskChampion backend of `05-taskwarrior`.
- `02-languages/08-node` — npm for `tokscale` inside `04-cli-extensions`.
- `03-dotfiles/01-repo` — `.taskrc` file present for symlink by
  `05-taskwarrior`.
