#!/usr/bin/env bash
# =============================================================================
# install/03-dotfiles/02-runtime-deps.sh
#
# Lifts oh-my-zsh and Tmux Plugin Manager from legacy repo-submodule
# paths to their natural runtime locations:
#   ~/.oh-my-zsh
#   ~/.tmux/plugins/tpm
#
# Migrates from the earlier submodule-inside-dotfiles layout when
# detected; otherwise clones fresh. Leaves unknown pre-existing paths
# alone.
#
# Required by 03-dotfiles/03-p10k.sh + 04-omz-plugins.sh (drop content
# into ~/.oh-my-zsh/custom/) and by 04-editors/02-tmux-plugins.sh
# (runs TPM from ~/.tmux/plugins/tpm).
# =============================================================================
set -euo pipefail

# Sourcing guard (dual-mode: works when sourced or executed)
if [[ -n "${_DOTFILES_RUNTIME_DEPS_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_RUNTIME_DEPS_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command git

# Resolve the dotfiles repo root (two levels up from this script)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
LEGACY_OH_MY_ZSH_DIR="$DOTFILES_DIR/.oh-my-zsh"
TPM_DIR="$HOME/.tmux/plugins/tpm"
LEGACY_TPM_DIR="$DOTFILES_DIR/.tmux/plugins/tpm"

# ---------------------------------------------------------------------------
# Helpers (runtime-deps-specific; kept local rather than in lib/)
# ---------------------------------------------------------------------------
runtime_path_is_legacy_symlink() {
    local runtime_path="$1"
    local legacy_path="$2"
    local resolved_path

    if [[ ! -L "$runtime_path" ]]; then
        return 1
    fi

    resolved_path="$(readlink -f "$runtime_path" 2>/dev/null || true)"
    [[ "$resolved_path" == "$legacy_path" ]]
}

ensure_runtime_git_checkout() {
    local label="$1"
    local runtime_path="$2"
    local legacy_path="$3"
    local repo_url="$4"

    mkdir -p "$(dirname "$runtime_path")"

    if runtime_path_is_legacy_symlink "$runtime_path" "$legacy_path"; then
        rm -f "$runtime_path"
        if [[ -d "$legacy_path" ]]; then
            mv "$legacy_path" "$runtime_path"
            ok "Migrated $label from repo checkout to $runtime_path"
            return 0
        fi
    fi

    if [[ ! -e "$runtime_path" && -d "$legacy_path" ]]; then
        mv "$legacy_path" "$runtime_path"
        ok "Migrated $label from repo checkout to $runtime_path"
        return 0
    fi

    if [[ -d "$runtime_path/.git" ]]; then
        ok "$label already installed"
        return 0
    fi

    if [[ ! -e "$runtime_path" ]]; then
        info "Installing $label..."
        git clone --depth=1 "$repo_url" "$runtime_path"
        ok "$label installed"
    else
        warn "$label path $runtime_path exists but is not a git checkout; leaving it untouched"
    fi
}

# ---------------------------------------------------------------------------
# Lift oh-my-zsh and TPM to their runtime locations
# ---------------------------------------------------------------------------
ensure_runtime_git_checkout "oh-my-zsh" "$OH_MY_ZSH_DIR" "$LEGACY_OH_MY_ZSH_DIR" \
    "https://github.com/ohmyzsh/ohmyzsh.git"
ensure_runtime_git_checkout "Tmux Plugin Manager" "$TPM_DIR" "$LEGACY_TPM_DIR" \
    "https://github.com/tmux-plugins/tpm.git"
