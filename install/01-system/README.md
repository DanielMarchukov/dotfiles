# 01-system

System-level packages and the foundation every other bucket depends on.

## Scope

- `01-packages.sh` — apt packages required by downstream toolchains:
  `sudo`, `git`, `curl`, `wget`, `jq`, `build-essential`, `cmake`,
  `unzip`, `python3`, `pipx`, `stow`, `fontconfig`, `sqlite3`, `zsh`,
  `tmux`, `fd-find`, `bat`, `ripgrep`, `zoxide`, `uuid-dev`,
  `libgnutls28-dev`, plus Ubuntu `fd`/`batcat` symlinks and `pipx
  ensurepath`.
- `02-locale.sh` — generates `en_US.UTF-8` and sets it as the system
  default. Fixes the NVM `manpath: can't set the locale` warning on
  fresh WSL installs.

## Ordering

- `01-packages` must run before `02-locale` (locale generation
  assumes `locales` package available).
- This bucket runs first overall. Every other bucket assumes its
  outputs are present.

## Produces for downstream

- `apt`-installed binaries on default PATH.
- `pipx` available for Python-tool installs (used by `02-languages`
  and `05-tools`).
- `stow` binary (consumed by `03-dotfiles/05-stow.sh`).
- `git`/`curl`/`wget` (universally consumed).
- Working UTF-8 locale so `nvm.sh` and other locale-strict tools stay
  quiet.
