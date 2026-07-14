#!/usr/bin/env bash
# =============================================================================
# test/verify-tealdeer.sh
#
# install/05-tools/05-tealdeer.sh — release install with tag-resolution
# fallback and version idempotence. curl/jq/uname are stubbed so the real
# resolve+download+install path runs offline.
# =============================================================================
set -uo pipefail

if [[ -n "${_DOTFILES_VERIFY_TEALDEER_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_VERIFY_TEALDEER_SH_LOADED=1

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

TEALDEER="$ROOT_DIR/install/05-tools/05-tealdeer.sh"
ASSET='tealdeer-linux-x86_64-musl'

# ---------------------------------------------------------------------------
describe "tealdeer: tag lookup fails -> installs via the latest/download alias"
c="$(sandbox tld-fallback)"
fb="$c/fakebin"; log="$c/work/curl.log"; : >"$log"
stub_uname "$fb"
stub_jq "$fb"
stub "$fb" curl <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$log"
out=""; url=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in -o) out="\$2"; shift 2 ;; http*) url="\$1"; shift ;; *) shift ;; esac
done
case "\$url" in
  https://api.github.com/*)                                exit 22 ;;  # API 403
  https://github.com/*/releases/latest)                    exit 28 ;;  # redirect timeout
  *releases/latest/download/$ASSET)
    printf '#!/usr/bin/env bash\n[[ "\$1" == "--version" ]] && { echo "tealdeer 1.7.2"; exit 0; }\nexit 0\n' >"\$out"
    chmod +x "\$out"; exit 0 ;;
esac
printf 'unexpected curl url: %s\n' "\$url" >&2
exit 1
EOF
run_module "$TEALDEER" "$c"
assert_success "$RUN_RC" "installer falls back and succeeds"
assert_executable "$c/home/.local/bin/tldr-real" "binary installed at tldr-real"
assert_executable "$c/home/.local/bin/tldr" "runnable tldr (wrapper or symlink) created"
assert_contains "releases/latest/download/$ASSET" "$log" "downloaded the latest-alias asset"

# ---------------------------------------------------------------------------
describe "tealdeer: already at the resolved version -> no download"
c="$(sandbox tld-idempotent)"
fb="$c/fakebin"; log="$c/work/curl.log"; : >"$log"
mkdir -p "$c/home/.local/bin"
stub "$c/home/.local/bin" tldr <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "--version" ]] && { echo "tealdeer 1.7.2"; exit 0; }
exit 0
EOF
stub_uname "$fb"
stub_jq "$fb"
stub "$fb" curl <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$log"
url=""; for a in "\$@"; do [[ "\$a" == http* ]] && url="\$a"; done
case "\$url" in
  https://api.github.com/*) printf '{"tag_name":"v1.7.2"}\n'; exit 0 ;;
esac
printf 'unexpected curl url: %s\n' "\$url" >&2
exit 1
EOF
run_module "$TEALDEER" "$c"
assert_success "$RUN_RC" "installer exits 0"
assert_contains "already installed" "$RUN_OUT" "reports already installed"
assert_not_contains "releases/download/" "$log" "did not download a release asset"

harness_summary
