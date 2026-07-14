#!/usr/bin/env bash
# =============================================================================
# test/verify-cargo-tools.sh
#
# Contract test for the cargo-installed tools: each must invoke `cargo install`
# with the right crate/source when its command is absent, and skip cargo when
# already present. Table-driven; cargo/uname are stubbed.
# =============================================================================
set -uo pipefail

if [[ -n "${_DOTFILES_VERIFY_CARGO_TOOLS_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_VERIFY_CARGO_TOOLS_SH_LOADED=1

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

# command | module | needle expected in the cargo invocation log
CARGO_MODULES=(
    "pay-respects|05-tools/03-pay-respects.sh|install pay-respects"
    "tdf|05-tools/20-tdf.sh|install --git https://github.com/itsjunetime/tdf.git"
)

seed_cargo_stub() {
    local fb="$1" log="$2"
    stub "$fb" cargo <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$log"
exit 0
EOF
}

for entry in "${CARGO_MODULES[@]}"; do
    IFS='|' read -r cmd rel needle <<<"$entry"
    module="$ROOT_DIR/install/$rel"

    describe "cargo: $cmd is installed via cargo when absent"
    c="$(sandbox "cargo-$cmd-install")"
    cargolog="$c/work/cargo.log"; : >"$cargolog"
    stub_uname "$c/fakebin"
    seed_cargo_stub "$c/fakebin" "$cargolog"
    run_module "$module" "$c"
    assert_success "$RUN_RC" "$cmd installer exits 0"
    assert_contains "$needle" "$cargolog" "cargo invoked for $cmd"

    describe "cargo: $cmd is a no-op when already present"
    c="$(sandbox "cargo-$cmd-idem")"
    cargolog="$c/work/cargo.log"; : >"$cargolog"
    stub_uname "$c/fakebin"
    seed_cargo_stub "$c/fakebin" "$cargolog"
    stub "$c/fakebin" "$cmd" <<EOF
#!/usr/bin/env bash
[[ "\$1" == "--version" ]] && { echo "$cmd 1.0.0"; exit 0; }
exit 0
EOF
    run_module "$module" "$c"
    assert_success "$RUN_RC" "$cmd installer exits 0"
    assert_empty "$cargolog" "cargo was not invoked for $cmd"
done

harness_summary
