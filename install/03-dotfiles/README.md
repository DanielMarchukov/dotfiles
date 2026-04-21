# 03-dotfiles

Dotfiles repo sync, OMZ/TPM runtime setup, plugin/theme cloning, stow
symlinking, and hardcoded-path patching.

## Scope

- `01-repo.sh` — git submodule init for `.config` and its nested
  `nvim`/`tmux` submodules. (The initial clone of the dotfiles repo
  itself stays in `bootstrap.sh` because `install/` does not exist
  until after clone.)
- `02-runtime-deps.sh` — lift oh-my-zsh and Tmux Plugin Manager from
  legacy repo paths to their natural runtime locations: `~/.oh-my-zsh`
  and `~/.tmux/plugins/tpm`. Migrates from earlier submodule-inside-
  repo layouts; clones fresh otherwise.
- `03-p10k.sh` — clone Powerlevel10k into
  `~/.oh-my-zsh/custom/themes/powerlevel10k`.
- `04-omz-plugins.sh` — clone zsh-autosuggestions,
  zsh-syntax-highlighting, fzf-z, you-should-use, zsh-bat into
  `~/.oh-my-zsh/custom/plugins/`.
- `05-stow.sh` — back up conflicting files; run `stow --restow` for
  top-level dotfiles; per-item symlinks for `.config/*`. Preserves the
  ignore list and the wholesale-`.config`-symlink guard verbatim from
  `bootstrap.sh`. MUST add `install` to the ignore list.
- `06-patch-home.sh` — sed-replace hardcoded `/home/danmarchukov/`
  with `$HOME` in `.zshenv`, `.zprofile`, `.taskrc`.

## Ordering

- `01-repo` first — `.config` submodule must be synced before
  downstream reads its contents.
- `02-runtime-deps` provides `~/.oh-my-zsh` — required by `03-p10k`
  and `04-omz-plugins`.
- `03-p10k` and `04-omz-plugins` can swap — both just drop content
  into `~/.oh-my-zsh/custom/`.
- `05-stow` MUST run after 01 + 02 + 03 + 04 — stow reads the source
  tree once, everything must be in place.
- `06-patch-home` runs after `05-stow` so patched files are already
  symlinked.

## Produces for downstream

- `$HOME/.zshrc`, `$HOME/.tmux/*.conf`, `$HOME/.config/nvim`, etc.
  as symlinks into the dotfiles repo (consumed by `04-editors` for
  editor config; by `06-shell` for terminal config).
- `~/.oh-my-zsh` populated with theme + plugins (consumed on shell
  startup).
- `~/.tmux/plugins/tpm` installed (consumed by
  `04-editors/02-tmux-plugins.sh`).
- `$DOTFILES_DIR/.taskrc` present for manual symlinking by
  `05-tools/05-taskwarrior.sh`.
