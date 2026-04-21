# 04-editors

Neovim (binary + plugin sync) and tmux plugins.

## Scope

- `01-neovim.sh` — Neovim latest stable release tarball extracted to
  `/opt`, symlinked to `/usr/local/bin/nvim`.
- `02-tmux-plugins.sh` — runs TPM's `install_plugins` against the
  configured plugin list. TPM itself lives at `~/.tmux/plugins/tpm`
  (runtime location, not stow-managed).
- `03-neovim-plugins.sh` — headless `nvim +Lazy! sync`, Mason registry
  refresh, Mason Java tools install (`jdtls`, `java-debug-adapter`,
  `java-test`).

## Ordering

- `01-neovim` before `03-neovim-plugins` — plugin sync needs the nvim
  binary.
- `02-tmux-plugins` is independent of the other two within this bucket.

## Needs from upstream buckets

- `02-languages/01-temurin-jdk` — Mason's `jdtls` resolves to Temurin's
  JAVA_HOME.
- `02-languages/04-cpp-toolchain` — clang used by Neovim's tree-sitter
  parsers on first sync.
- `03-dotfiles/02-runtime-deps` — TPM installed at
  `~/.tmux/plugins/tpm` (consumed by `02-tmux-plugins`).
- `03-dotfiles/05-stow` — `~/.config/nvim` symlink and tmux config
  symlinks must exist.
