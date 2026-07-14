#!/usr/bin/env bash
# =============================================================================
# test/verify-patch-home.sh
#
# common.sh:patch_home — rewrites the legacy hardcoded /home/danmarchukov/
# prefix to the live $HOME in tracked rc files. The module (06-patch-home.sh)
# targets the real repo files, so we test the function directly against
# sandbox files with a sandbox $HOME instead.
# =============================================================================
set -uo pipefail

if [[ -n "${_DOTFILES_VERIFY_PATCH_HOME_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_VERIFY_PATCH_HOME_SH_LOADED=1

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

# patch <case_dir> <file> — run common.sh:patch_home in a hermetic subshell
# with HOME=<case>/home, so the replacement expands to the sandbox home.
patch() {
    local case_dir="$1" file="$2"
    RUN_OUT="$case_dir/stdout"; RUN_ERR="$case_dir/stderr"
    env -i HOME="$case_dir/home" ROOT_DIR="$ROOT_DIR" TARGET="$file" \
        PATH="$case_dir/fakebin:$HARNESS_COREUTILS" \
        bash -c 'set -uo pipefail; source "$ROOT_DIR/install/lib/common.sh"; patch_home "$TARGET"' \
        >"$RUN_OUT" 2>"$RUN_ERR"
    RUN_RC=$?
}

# ---------------------------------------------------------------------------
describe "patch_home: rewrites /home/danmarchukov/ to \$HOME"
c="$(sandbox ph-rewrite)"
f="$c/work/.zshenv"
printf 'export PATH=/home/danmarchukov/.local/bin:$PATH\n' >"$f"
patch "$c" "$f"
assert_success "$RUN_RC" "returns success"
assert_not_contains "/home/danmarchukov/" "$f" "legacy prefix removed"
assert_contains "$c/home/.local/bin" "$f" "rewritten to sandbox HOME"

describe "patch_home: is idempotent on an already-patched file"
before="$(cat "$f")"
patch "$c" "$f"
assert_success "$RUN_RC" "returns success"
assert_eq "$(cat "$f")" "$before" "second run leaves the file unchanged"

describe "patch_home: leaves files without the legacy prefix untouched"
c="$(sandbox ph-noop)"
f="$c/work/.zprofile"
printf 'export EDITOR=nvim\n' >"$f"
patch "$c" "$f"
assert_success "$RUN_RC" "returns success"
assert_eq "$(cat "$f")" "export EDITOR=nvim" "content unchanged"

describe "patch_home: tolerates a missing file"
c="$(sandbox ph-missing)"
patch "$c" "$c/work/does-not-exist"
assert_success "$RUN_RC" "returns success (no-op)"

harness_summary
