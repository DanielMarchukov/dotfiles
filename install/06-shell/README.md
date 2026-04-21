# 06-shell

Shell-level environment: default shell selection and terminal font.

## Scope

- `01-default-shell.sh` — `chsh -s zsh` if the current shell isn't
  already zsh.
- `02-nerd-font.sh` — MesloLGS Nerd Font (needed by Powerlevel10k for
  icons). Downloads Regular/Bold/Italic/Bold-Italic, refreshes
  `fc-cache`.

## Ordering

- Fully independent — both steps can run in either order.

## Needs from upstream buckets

- `01-system` — `zsh` installed, `fontconfig` + `curl` available.

## Does NOT need

- `03-dotfiles` — `chsh` and font install work even before the
  dotfiles repo is wired up. Placement after dotfiles is cosmetic,
  not load-bearing.
