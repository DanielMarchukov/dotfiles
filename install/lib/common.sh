#!/usr/bin/env bash
# =============================================================================
# install/lib/common.sh
#
# Universal helpers for install/*.sh scripts. Source this first.
#   source "$(dirname "$0")/lib/common.sh"
#
# Provides: logging (info/ok/warn/err), platform detection, PATH +
# toolchain env setup, backup + patch-home helpers.
#
# Callers are responsible for `set -euo pipefail` — libraries must not
# unilaterally change shell options.
# =============================================================================

# Sourcing guard — avoid re-init when sourced multiple times in one shell.
[[ -n "${_DOTFILES_COMMON_SH_LOADED:-}" ]] && return 0
_DOTFILES_COMMON_SH_LOADED=1

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[0;32m[ OK ]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }
err()   { printf '\033[0;31m[ ERR]\033[0m  %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Paths and toolchain env continuity
# ---------------------------------------------------------------------------
# Each install-XX.sh runs in its own subshell; these make toolchains
# installed in earlier steps visible to later ones.
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
export PATH="$LOCAL_BIN:$PATH"

[[ -d "$HOME/.fzf/bin" ]] && export PATH="$HOME/.fzf/bin:$PATH"
# shellcheck source=/dev/null
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------
require_linux() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        err "This installer currently targets Linux/WSL."
        exit 1
    fi
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        err "Missing required command: $1"
        exit 1
    fi
}

arch_slug() {
    case "$(uname -m)" in
        x86_64|amd64)
            printf '%s\n' 'x86_64'
            ;;
        aarch64|arm64)
            printf '%s\n' 'aarch64'
            ;;
        *)
            err "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
}

apt_arch_slug() {
    case "$(arch_slug)" in
        x86_64) printf '%s\n' 'amd64' ;;
        aarch64) printf '%s\n' 'arm64' ;;
    esac
}

# ---------------------------------------------------------------------------
# Filesystem helpers
# ---------------------------------------------------------------------------
# BACKUP_DIR is computed once per shell (per sourcing). The orchestrator
# may export its own BACKUP_DIR to share across sibling scripts.
BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)}"
BACKUP_NEEDED="${BACKUP_NEEDED:-false}"

# Move a real file/dir to BACKUP_DIR; remove stale symlinks. No-op otherwise.
backup_if_real() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
        if [[ "$BACKUP_NEEDED" == false ]]; then
            mkdir -p "$BACKUP_DIR"
            BACKUP_NEEDED=true
        fi
        mv "$target" "$BACKUP_DIR/"
        info "Backed up $target"
    elif [[ -L "$target" ]]; then
        rm -f "$target"
    fi
}

# Replace hardcoded /home/danmarchukov/ with $HOME in a file. Idempotent:
# the grep guard makes it a no-op once the file is patched.
patch_home() {
    local file="$1"
    if [[ -f "$file" ]] && grep -q '/home/danmarchukov/' "$file" 2>/dev/null; then
        sed -i "s|/home/danmarchukov/|$HOME/|g" "$file"
        ok "Patched paths in $(basename "$file")"
    fi
}
