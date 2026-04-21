#!/usr/bin/env bash
# =============================================================================
# install/03-dotfiles/05-stow.sh
#
# Backs up conflicting $HOME files, invokes `stow --restow` to install
# top-level dotfiles, then per-item symlinks for .config/* and .github/*.
#
# Preserves the wholesale-.config-symlink guard and the legacy repo-
# absolute-link cleanup verbatim from bootstrap.sh Section 12.
#
# Depends on 03-dotfiles/01-repo.sh (.config submodule + contents),
# 02-runtime-deps.sh (OMZ + TPM at runtime paths), 03-p10k.sh +
# 04-omz-plugins.sh (theme + plugins must exist in ~/.oh-my-zsh/custom/
# before stow reads the tree — though the current ignore list actually
# skips .oh-my-zsh in stow; they're consumed on shell startup).
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_STOW_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_STOW_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command stow

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ---------------------------------------------------------------------------
# Local helper (stow-specific)
# ---------------------------------------------------------------------------
remove_legacy_repo_absolute_symlink() {
    local target="$1"
    local link_target

    if [[ ! -L "$target" ]]; then
        return 0
    fi

    link_target="$(readlink "$target" 2>/dev/null || true)"
    if [[ "$link_target" == "$DOTFILES_DIR/"* ]]; then
        rm -f "$target"
        info "Removed legacy repo symlink $target -> $link_target"
    fi
}

# ---------------------------------------------------------------------------
# Top-level files stow will manage
# ---------------------------------------------------------------------------
STOW_FILES=(
    .zshrc .zshenv .zprofile .profile .bash_profile
    .p10k.zsh .gitignore_global .gitmodules
)

for f in "${STOW_FILES[@]}"; do
    backup_if_real "$HOME/$f"
done

# ---------------------------------------------------------------------------
# Refuse to proceed if ~/.config is a wholesale symlink to the submodule.
# CONFIG_ITEMS below would resolve through the link and wipe submodule
# contents via backup_if_real. Per-item symlinks only.
# ---------------------------------------------------------------------------
if [[ -L "$HOME/.config" ]]; then
    config_target="$(readlink -f "$HOME/.config" 2>/dev/null || true)"
    if [[ "$config_target" == "$DOTFILES_DIR/.config" ]]; then
        err "~/.config is a wholesale symlink to $DOTFILES_DIR/.config."
        err "Migrate to per-item symlinks before re-running:"
        err "  rm ~/.config && mkdir ~/.config"
        err "  mv $DOTFILES_DIR/.config/{atuin,gh,github-copilot,glab-cli,go} ~/.config/ 2>/dev/null || true"
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# .config items managed individually (don't replace the whole .config dir)
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.config"
CONFIG_ITEMS=(nvim tmux git just tealdeer)
for item in "${CONFIG_ITEMS[@]}"; do
    backup_if_real "$HOME/.config/$item"
done

# ---------------------------------------------------------------------------
# .github items are managed individually so Copilot/global GitHub state can
# coexist with other files under ~/.github without replacing the whole dir.
# ---------------------------------------------------------------------------
if [[ -d "$DOTFILES_DIR/.github" ]]; then
    mkdir -p "$HOME/.github"
    while IFS= read -r repo_github_file; do
        rel_path="${repo_github_file#"$DOTFILES_DIR/.github/"}"
        target_path="$HOME/.github/$rel_path"
        mkdir -p "$(dirname "$target_path")"
        backup_if_real "$target_path"
    done < <(find "$DOTFILES_DIR/.github" -type f | sort)
fi

# Items managed outside of stow — drop stale symlinks so stow's restow scan
# doesn't trip on absolute symlinks pointing back into the stow dir.
backup_if_real "$HOME/.taskrc"

# Legacy hand-made links inside real directories confuse stow: they point into
# the repo, but because they're absolute, stow won't treat them as owned links.
if [[ -d "$HOME/bin" && -d "$DOTFILES_DIR/bin" ]]; then
    shopt -s nullglob
    for repo_bin_item in "$DOTFILES_DIR"/bin/*; do
        remove_legacy_repo_absolute_symlink "$HOME/bin/$(basename "$repo_bin_item")"
    done
    shopt -u nullglob
fi

if [[ "$BACKUP_NEEDED" == true ]]; then
    ok "Backups saved to $BACKUP_DIR"
fi

# ---------------------------------------------------------------------------
# Stow top-level dotfiles (--restow is idempotent — re-links if already stowed)
# ---------------------------------------------------------------------------
info "Stowing dotfiles..."
stow --restow \
    -d "$(dirname "$DOTFILES_DIR")" \
    -t "$HOME" \
    --ignore='\.config' \
    --ignore='\.github' \
    --ignore='\.claude' \
    --ignore='\.local' \
    --ignore='\.oh-my-zsh' \
    --ignore='\.tmux' \
    --ignore='\.git' \
    --ignore='\.gitconfig' \
    --ignore='\.gitignore' \
    --ignore='\.codex' \
    --ignore='\.taskrc' \
    --ignore='windows' \
    --ignore='install' \
    --ignore='bootstrap\.sh' \
    --ignore='bootstrap_v2\.sh' \
    --ignore='install-cli-extensions\.sh' \
    --ignore='install-mcp\.sh' \
    --ignore='README.*' \
    "$(basename "$DOTFILES_DIR")"

# Symlink .config items individually (ln -sfn is idempotent)
for item in "${CONFIG_ITEMS[@]}"; do
    if [[ -d "$DOTFILES_DIR/.config/$item" ]]; then
        ln -sfn "$DOTFILES_DIR/.config/$item" "$HOME/.config/$item"
        ok "Linked ~/.config/$item"
    fi
done

if [[ -d "$DOTFILES_DIR/.github" ]]; then
    while IFS= read -r repo_github_file; do
        rel_path="${repo_github_file#"$DOTFILES_DIR/.github/"}"
        target_path="$HOME/.github/$rel_path"
        ln -sfn "$repo_github_file" "$target_path"
        ok "Linked ~/.github/$rel_path"
    done < <(find "$DOTFILES_DIR/.github" -type f | sort)
fi

ok "Dotfiles stowed"
