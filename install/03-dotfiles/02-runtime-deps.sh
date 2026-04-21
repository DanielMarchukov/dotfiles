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

# Detect and remove a stale submodule leftover: a directory whose .git
# is a gitlink marker for a submodule that's no longer part of the
# superproject. Two common patterns after a submodule removal:
#   1. Gitlink target (`.git/modules/<path>`) was also removed — gitlink
#      points to a non-existent dir.
#   2. Gitlink target still exists (orphaned module metadata) but
#      `.gitmodules` no longer declares the path — module is a zombie.
# In both cases, the working tree is safe to rm, plus any orphaned
# module metadata directory it references.
cleanup_stale_submodule_leftover() {
    local target="$1"
    local gitlink_file="$target/.git"

    # Must be a directory with .git as a FILE (gitlink marker)
    if [[ ! -d "$target" || ! -f "$gitlink_file" ]]; then
        return 0
    fi

    # Walk up from the parent to find the superproject root. Start above
    # $target so a .gitmodules file inside the submodule itself (which TPM
    # and others may ship) can't be mistaken for the superproject's.
    local superproject_root
    superproject_root="$(dirname "$target")"
    while [[ "$superproject_root" != "/" && ! -f "$superproject_root/.gitmodules" ]]; do
        superproject_root="$(dirname "$superproject_root")"
    done

    local gitdir_relative resolved_gitdir=""
    gitdir_relative="$(awk -F': ' '/^gitdir:/{print $2; exit}' "$gitlink_file" 2>/dev/null || true)"
    if [[ -n "$gitdir_relative" ]]; then
        resolved_gitdir="$(cd "$target" 2>/dev/null && readlink -f "$gitdir_relative" 2>/dev/null || true)"
    fi

    local stale_reason=""

    # Pattern 1: gitlink points to a non-existent gitdir
    if [[ -z "$resolved_gitdir" || ! -d "$resolved_gitdir" ]]; then
        stale_reason="gitlink points to non-existent gitdir"
    fi

    # Pattern 2: superproject's .gitmodules doesn't declare this path
    if [[ -z "$stale_reason" && -f "$superproject_root/.gitmodules" ]]; then
        local rel_path declared_paths
        rel_path="${target#$superproject_root/}"
        declared_paths="$(git config -f "$superproject_root/.gitmodules" \
            --get-regexp '^submodule\..*\.path$' 2>/dev/null \
            | awk '{print $2}')"
        if ! echo "$declared_paths" | grep -qxF "$rel_path"; then
            stale_reason="path not declared in $superproject_root/.gitmodules"
        fi
    fi

    if [[ -n "$stale_reason" ]]; then
        info "Removing stale submodule leftover at $target ($stale_reason)"
        rm -rf "$target"
        if [[ -n "$resolved_gitdir" && -d "$resolved_gitdir" ]]; then
            info "Removing orphaned module metadata at $resolved_gitdir"
            rm -rf "$resolved_gitdir"
        fi
    fi
}

ensure_runtime_git_checkout() {
    local label="$1"
    local runtime_path="$2"
    local legacy_path="$3"
    local repo_url="$4"

    mkdir -p "$(dirname "$runtime_path")"

    # Remove stale post-submodule-removal leftovers before deciding what
    # to do next. Applies to both runtime_path (in case it resolves to a
    # stale dir via symlink) and legacy_path.
    cleanup_stale_submodule_leftover "$runtime_path"
    cleanup_stale_submodule_leftover "$legacy_path"

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
# Fix legacy wholesale ~/.tmux symlink
# ---------------------------------------------------------------------------
# Pre-modernization stow layout linked the entire ~/.tmux dir to
# $DOTFILES_DIR/.tmux. After the submodule was removed, stow now
# ignores .tmux, but the existing wholesale symlink persists and
# causes any runtime content (e.g., TPM) to land inside the repo tree.
# Convert to a real ~/.tmux directory and relocate TPM if needed.
repair_legacy_tmux_symlink() {
    local legacy_tmux_dir="$DOTFILES_DIR/.tmux"
    if [[ ! -L "$HOME/.tmux" ]]; then
        return 0
    fi

    local resolved
    resolved="$(readlink -f "$HOME/.tmux" 2>/dev/null || true)"
    if [[ "$resolved" != "$legacy_tmux_dir" ]]; then
        return 0
    fi

    info "Repairing legacy ~/.tmux wholesale symlink..."
    rm -f "$HOME/.tmux"
    mkdir -p "$HOME/.tmux/plugins"

    # Move any TPM checkout that landed inside the repo out to the
    # real runtime location.
    if [[ -d "$legacy_tmux_dir/plugins/tpm" ]]; then
        mv "$legacy_tmux_dir/plugins/tpm" "$HOME/.tmux/plugins/tpm"
        ok "Moved TPM from $legacy_tmux_dir/plugins/tpm to $HOME/.tmux/plugins/tpm"
    fi

    # Remove the now-empty repo-side .tmux scaffolding (gitignored)
    if [[ -d "$legacy_tmux_dir" ]]; then
        rm -rf "$legacy_tmux_dir"
    fi

    ok "~/.tmux is now a real directory"
}

# ---------------------------------------------------------------------------
# Lift oh-my-zsh and TPM to their runtime locations
# ---------------------------------------------------------------------------
repair_legacy_tmux_symlink
ensure_runtime_git_checkout "oh-my-zsh" "$OH_MY_ZSH_DIR" "$LEGACY_OH_MY_ZSH_DIR" \
    "https://github.com/ohmyzsh/ohmyzsh.git"
ensure_runtime_git_checkout "Tmux Plugin Manager" "$TPM_DIR" "$LEGACY_TPM_DIR" \
    "https://github.com/tmux-plugins/tpm.git"
