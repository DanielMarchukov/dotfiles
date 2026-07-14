#!/usr/bin/env bash
# =============================================================================
# test/verify-install-nvim.sh
#
# install-nvim.sh — install/upgrade Neovim from GitHub releases. Covers the
# API-403 fallback to the channel-alias download and version idempotence
# from the release-body version. curl/jq/uname/sudo are stubbed; the tarball
# is fabricated locally, so nothing touches the network or /opt.
# =============================================================================
set -uo pipefail

if [[ -n "${_DOTFILES_VERIFY_INSTALL_NVIM_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_VERIFY_INSTALL_NVIM_SH_LOADED=1

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

INSTALL_NVIM="$ROOT_DIR/install-nvim.sh"
TARBALL='nvim-linux-x86_64.tar.gz'
DL_URL="https://github.com/neovim/neovim/releases/download/stable/$TARBALL"

# make_nvim_tarball <dest> — a .tar.gz whose bin/nvim reports v0.12.4.
make_nvim_tarball() {
    local dest="$1" stage="$2"
    mkdir -p "$stage/nvim-linux-x86_64/bin"
    cat >"$stage/nvim-linux-x86_64/bin/nvim" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == "--version" ]] && { printf 'NVIM v0.12.4\n'; exit 0; }
printf 'fake nvim\n'
EOF
    chmod +x "$stage/nvim-linux-x86_64/bin/nvim"
    tar -czf "$dest" -C "$stage" nvim-linux-x86_64
}

# ---------------------------------------------------------------------------
describe "install-nvim: API 403 -> downloads the stable channel alias directly"
c="$(sandbox nvim-403)"
fb="$c/fakebin"; log="$c/work/curl.log"; : >"$log"
install_root="$c/work/install-root"; mkdir -p "$install_root"
make_nvim_tarball "$c/work/$TARBALL" "$c/work/stage"
stub_uname "$fb"
stub_jq "$fb"
stub_sudo "$fb"
stub "$fb" curl <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$log"
out=""; url=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in -o) out="\$2"; shift 2 ;; http*) url="\$1"; shift ;; *) shift ;; esac
done
case "\$url" in
  https://api.github.com/*) exit 22 ;;                               # API 403
  $DL_URL) cp "$c/work/$TARBALL" "\$out"; exit 0 ;;                  # channel alias
esac
printf 'unexpected curl url: %s\n' "\$url" >&2
exit 1
EOF
run_module "$INSTALL_NVIM" "$c" \
    NVIM_INSTALL_ROOT="$install_root" \
    NVIM_SYMLINK="$fb/nvim"
assert_success "$RUN_RC" "installer falls back to the alias and succeeds"
assert_executable "$fb/nvim" "nvim symlink is runnable"
assert_contains "$DL_URL" "$log" "downloaded the stable channel alias"
assert_not_contains "https://github.com/neovim/neovim/releases/latest" "$log" "did not chase the releases/latest redirect"

# ---------------------------------------------------------------------------
describe "install-nvim: already at the release-body version -> no download"
c="$(sandbox nvim-idempotent)"
fb="$c/fakebin"; log="$c/work/curl.log"; : >"$log"
install_root="$c/work/install-root"; mkdir -p "$install_root"
stub "$fb" nvim <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == "--version" ]] && { printf 'NVIM v0.12.4\n'; exit 0; }
printf 'existing fake nvim\n'
EOF
stub_uname "$fb"
stub_jq "$fb"
stub_sudo "$fb"
stub "$fb" curl <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$log"
url=""; for a in "\$@"; do [[ "\$a" == http* ]] && url="\$a"; done
case "\$url" in
  https://api.github.com/*)
    printf '%s\n' '{"tag_name":"stable","body":"NVIM v0.12.4\nBuild type: Release"}'; exit 0 ;;
esac
printf 'unexpected curl url: %s\n' "\$url" >&2
exit 1
EOF
run_module "$INSTALL_NVIM" "$c" \
    NVIM_INSTALL_ROOT="$install_root" \
    NVIM_SYMLINK="$fb/nvim"
assert_success "$RUN_RC" "installer exits 0"
assert_contains "already up to date (v0.12.4)" "$RUN_OUT" "reports up to date"
assert_not_contains "releases/download/" "$log" "did not download a release asset"

harness_summary
