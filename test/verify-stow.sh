#!/usr/bin/env bash
# =============================================================================
# test/verify-stow.sh
#
# install/03-dotfiles/05-stow.sh — the module's own linking/backup/guard
# logic. GNU stow is stubbed to a no-op (the top-level stow call is not what
# we're verifying), so these run anywhere; what we assert is the per-item
# .config symlinking, the real-file backup, and the wholesale-.config-symlink
# safety guard. All writes land in a sandbox $HOME; the repo is only read.
# =============================================================================
set -uo pipefail

if [[ -n "${_DOTFILES_VERIFY_STOW_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_VERIFY_STOW_SH_LOADED=1

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

STOW="$ROOT_DIR/install/03-dotfiles/05-stow.sh"

# stow stub — satisfies require_command and no-ops the top-level stow pass.
seed_stow_stub() {
    stub "$1" stow <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
}

# ---------------------------------------------------------------------------
describe "stow: symlinks .config items individually into \$HOME"
c="$(sandbox stow-happy)"
seed_stow_stub "$c/fakebin"
run_module "$STOW" "$c"
assert_success "$RUN_RC" "installer exits 0"
if [[ -d "$ROOT_DIR/.config/nvim" ]]; then
    assert_symlink "$c/home/.config/nvim" "sandbox .config/nvim is a per-item symlink"
    assert_eq "$(readlink "$c/home/.config/nvim" 2>/dev/null)" "$ROOT_DIR/.config/nvim" \
        "sandbox .config/nvim points at the repo's .config/nvim"
else
    skip "repo .config/nvim submodule not checked out"
fi

# ---------------------------------------------------------------------------
describe "stow: backs up a real \$HOME file before linking"
c="$(sandbox stow-backup)"
seed_stow_stub "$c/fakebin"
printf 'pre-existing real zshrc\n' >"$c/home/.zshrc"
run_module "$STOW" "$c"
assert_success "$RUN_RC" "installer exits 0"
backup_copy="$(find "$c/home/.dotfiles-backup" -name .zshrc 2>/dev/null | head -1)"
assert_eq "$([[ -f "$backup_copy" ]] && echo yes)" "yes" "real .zshrc moved into the backup dir"
assert_contains "pre-existing real zshrc" "$backup_copy" "backup preserved the original contents"

# ---------------------------------------------------------------------------
describe "stow: refuses to run when ~/.config is a wholesale symlink to the repo"
c="$(sandbox stow-guard)"
seed_stow_stub "$c/fakebin"
ln -s "$ROOT_DIR/.config" "$c/home/.config"
run_module "$STOW" "$c"
assert_failure "$RUN_RC" "installer aborts"
assert_contains "wholesale symlink" "$RUN_ERR" "explains the wholesale-symlink hazard"

harness_summary
