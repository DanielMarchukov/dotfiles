#!/usr/bin/env bash
# =============================================================================
# Dotfiles Bootstrap (v2 — thin orchestrator)
#
# Minimal entry point that clones the dotfiles repo (if not present)
# and then runs every install/<bucket>/<step>.sh in bucket/step order.
# Each step script is self-contained: sources its own helpers, runs
# its own idempotency checks, and exits 0 on success.
#
# This lives alongside the legacy monolithic bootstrap.sh during the
# Phase 2 → Phase 3 migration window. Once bootstrap_v2.sh is verified
# end-to-end, it replaces bootstrap.sh as part of the Phase 3 swap.
#
# Usage:
#   curl -fsSL <raw-url> | bash      # fresh machine, self-clones
#   ./bootstrap_v2.sh                # in an already-cloned repo
#
# Environment:
#   SKIP_SECTIONS="04-cpp 05-tools/09-rga"
#     Space-separated. Each entry matches either a full tag
#     (`<bucket>/<step>`) or a bucket prefix.
# =============================================================================
set -euo pipefail

info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[0;32m[ OK ]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }
err()   { printf '\033[0;31m[ ERR]\033[0m  %s\n' "$*" >&2; }

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/DanielMarchukov/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/repos/dotfiles}"

# ---------------------------------------------------------------------------
# 1. Minimal prereqs for clone (works on curl|bash)
# ---------------------------------------------------------------------------
if ! command -v git &>/dev/null || ! command -v curl &>/dev/null; then
    info "Installing minimal clone prereqs (git, curl)..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq git curl
fi

# ---------------------------------------------------------------------------
# 2. Clone or reuse the dotfiles repo
# ---------------------------------------------------------------------------
if [[ -d "$DOTFILES_DIR/.git" ]]; then
    info "Using local dotfiles repo at $DOTFILES_DIR"
elif [[ -d "$HOME/repos/.git" ]]; then
    err "Expected dotfiles repo at $DOTFILES_DIR but found a git repo at $HOME/repos instead"
    err "Move or clone the dotfiles repo to $DOTFILES_DIR and re-run bootstrap"
    exit 1
else
    info "Cloning dotfiles repo into $DOTFILES_DIR..."
    mkdir -p "$(dirname "$DOTFILES_DIR")"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# ---------------------------------------------------------------------------
# 3. Shared state across step scripts
# ---------------------------------------------------------------------------
# One backup dir per bootstrap run so every `backup_if_real` call from
# any step lands in the same timestamped folder (common.sh respects
# this via BACKUP_DIR="${BACKUP_DIR:-...}").
export BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)}"

# ---------------------------------------------------------------------------
# 4. Run install steps in bucket/step order
# ---------------------------------------------------------------------------
INSTALL_DIR="$DOTFILES_DIR/install"
SKIP_SECTIONS="${SKIP_SECTIONS:-}"

if [[ ! -d "$INSTALL_DIR" ]]; then
    err "$INSTALL_DIR missing — did the clone succeed?"
    exit 1
fi

skip_count=0
fail_count=0
run_count=0

for script in "$INSTALL_DIR"/??-*/??-*.sh; do
    [[ -x "$script" ]] || continue

    name="${script#"$INSTALL_DIR/"}"
    tag="${name%.sh}"

    # Match either a full tag or a bucket-prefix entry in SKIP_SECTIONS
    skipped=false
    for skip in $SKIP_SECTIONS; do
        if [[ "$tag" == "$skip" || "$tag" == "$skip/"* ]]; then
            warn "Skipping $tag (SKIP_SECTIONS=$skip)"
            skip_count=$((skip_count + 1))
            skipped=true
            break
        fi
    done
    [[ "$skipped" == true ]] && continue

    printf '\n\033[1m=== %s ===\033[0m\n' "$tag"
    if "$script"; then
        run_count=$((run_count + 1))
    else
        fail_count=$((fail_count + 1))
        err "Step $tag exited non-zero; aborting bootstrap"
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# 5. Summary
# ---------------------------------------------------------------------------
echo
ok "Bootstrap complete: $run_count step(s) succeeded, $skip_count skipped, $fail_count failed"
echo
info "Next steps:"
info "  1. Log out and back in (or run: exec zsh)"
info "  2. Set your terminal font to 'MesloLGS NF'"
info "  3. Run 'gh auth login' to authenticate GitHub CLI"
info "  4. Per project: run 'basic-memory project add <name> .' to init memory vault"
info "     (Set CONTEXT7_API_KEY in ~/.config/secrets/mcp.env to enable context7 MCP)"
echo
