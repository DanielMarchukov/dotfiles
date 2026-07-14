#!/usr/bin/env bash
# =============================================================================
# test/verify-apt-tools.sh
#
# Contract test for the plain apt-installed tools: each must (a) install the
# right package via apt when the command is absent, and (b) skip apt entirely
# when the command is already present. Table-driven so one file covers every
# such module. apt-get/sudo/uname are stubbed — nothing touches real apt.
# =============================================================================
set -uo pipefail

if [[ -n "${_DOTFILES_VERIFY_APT_TOOLS_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_VERIFY_APT_TOOLS_SH_LOADED=1

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

# command | apt-package | module (relative to install/)
APT_MODULES=(
    "delta|git-delta|05-tools/13-git-delta.sh"
    "git-absorb|git-absorb|05-tools/14-git-absorb.sh"
    "hyperfine|hyperfine|05-tools/15-hyperfine.sh"
    "just|just|05-tools/16-just.sh"
    "timew|timewarrior|05-tools/17-timewarrior.sh"
    "mosh|mosh|05-tools/18-mosh.sh"
    "direnv|direnv|05-tools/12-direnv.sh"
)

for entry in "${APT_MODULES[@]}"; do
    IFS='|' read -r cmd pkg rel <<<"$entry"
    module="$ROOT_DIR/install/$rel"

    describe "apt: $pkg installs the package when '$cmd' is absent"
    c="$(sandbox "apt-$pkg-install")"
    aptlog="$c/work/apt.log"; : >"$aptlog"
    stub_uname "$c/fakebin"
    stub_sudo "$c/fakebin"
    stub_apt "$c/fakebin" "$aptlog"
    run_module "$module" "$c"
    assert_success "$RUN_RC" "$pkg installer exits 0"
    assert_contains "install -y -qq $pkg" "$aptlog" "apt-get asked to install $pkg"

    describe "apt: $pkg is a no-op when '$cmd' is already present"
    c="$(sandbox "apt-$pkg-idem")"
    aptlog="$c/work/apt.log"; : >"$aptlog"
    stub_uname "$c/fakebin"
    stub_sudo "$c/fakebin"
    stub_apt "$c/fakebin" "$aptlog"
    stub "$c/fakebin" "$cmd" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    run_module "$module" "$c"
    assert_success "$RUN_RC" "$pkg installer exits 0"
    assert_contains "already installed" "$RUN_OUT" "$pkg reports already installed"
    assert_empty "$aptlog" "apt-get was not invoked for $pkg"
done

harness_summary
