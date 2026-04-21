# 05-tools

CLI productivity tools. Each install_X function from the former repo-
root `install-cli-extensions.sh` is now its own script here, one tool
per file.

## Scope

- `01-fzf.sh` — fzf from git (apt version is too old for the OMZ fzf
  plugin).
- `02-github-cli.sh` — `gh` via the official GitHub apt repo.
- `03-pay-respects.sh` — `thefuck` replacement (`thefuck` broken on
  Python 3.12+); cargo install.
- `04-atuin.sh` — shell history search, official GitHub release.
- `05-tealdeer.sh` — `tldr` client, official release plus optional
  `$DOTFILES_DIR/bin/tldr` wrapper (falls back to direct symlink).
- `06-yq.sh` — yq v4 (mikefarah), official release.
- `07-glab.sh` — GitLab CLI, official release with apt fallback.
- `08-watchexec.sh` — official release with cargo fallback.
- `09-rga.sh` — ripgrep-all, official release with cargo fallback;
  also apt-installs ffmpeg/pandoc/poppler-utils for content
  extraction.
- `10-git-branchless.sh` — official release with cargo fallback.
- `11-tokscale.sh` — npm install (multi-provider LLM token-usage).
- `12-direnv.sh` — apt install.
- `13-git-delta.sh` — apt install (`delta` binary).
- `14-git-absorb.sh` — apt install.
- `15-hyperfine.sh` — apt install.
- `16-just.sh` — apt install.
- `17-timewarrior.sh` — apt install (`timew` binary).
- `18-mosh.sh` — apt install.
- `19-taskwarrior.sh` — Taskwarrior 3.x built from source (apt only
  ships 2.x). Also symlinks `.taskrc` manually (NOT via stow — the
  stow `--ignore` list skips `.taskrc`) and patches the home path in
  it.

## Ordering

- Fully reorderable — no intra-bucket edges. All siblings.

## Needs from upstream buckets

- `01-system` — apt packages, pipx, curl.
- `02-languages/07-rust` — cargo for `03-pay-respects`, the cargo
  fallbacks inside `08-watchexec` / `09-rga` / `10-git-branchless`,
  and the TaskChampion backend of `19-taskwarrior`.
- `02-languages/08-node` — npm for `11-tokscale`.
- `03-dotfiles/01-repo` — `.taskrc` file present for manual symlink
  by `19-taskwarrior`.
