# 01-system

System-level packages and the foundation every other bucket depends on.

## Scope

Apt packages required by downstream toolchains: `sudo`, `git`, `curl`,
`wget`, `jq`, `build-essential`, `cmake`, `unzip`, `python3`, `pipx`,
`stow`, `fontconfig`, `sqlite3`, `zsh`, `tmux`, `fd-find`, `bat`,
`ripgrep`, `zoxide`, `uuid-dev`, `libgnutls28-dev`, and the
`fd`/`batcat` symlinks for Ubuntu naming quirks.

## Ordering

- Runs first. Every other bucket assumes these packages are present.
- Single step — no intra-bucket concerns.

## Produces for downstream

- `apt`-installed binaries on default PATH.
- `pipx` available for Python-tool installs (used by `02-languages`
  and `05-tools`).
- `stow` binary (consumed by `03-dotfiles/05-stow.sh`).
- `git`/`curl`/`wget` (universally consumed).
