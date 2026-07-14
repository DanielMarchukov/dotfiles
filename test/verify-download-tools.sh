#!/usr/bin/env bash
# =============================================================================
# test/verify-download-tools.sh
#
# End-to-end test of a release-binary installer that uses the shared
# curl_download helper (yq): it must download and install the binary when
# absent, and skip when the right version is already present. curl/uname are
# stubbed; the archive-candidate and tag-resolution mechanisms these modules
# share are unit-tested in verify-downloads.sh.
# =============================================================================
set -uo pipefail

if [[ -n "${_DOTFILES_VERIFY_DOWNLOAD_TOOLS_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_VERIFY_DOWNLOAD_TOOLS_SH_LOADED=1

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

YQ="$ROOT_DIR/install/05-tools/06-yq.sh"

# ---------------------------------------------------------------------------
describe "yq: downloads and installs the v4 binary when absent"
c="$(sandbox yq-install)"
fb="$c/fakebin"; log="$c/work/curl.log"; : >"$log"
stub_uname "$fb"
stub "$fb" curl <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$log"
out=""; url=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in -o) out="\$2"; shift 2 ;; http*) url="\$1"; shift ;; *) shift ;; esac
done
case "\$url" in
  *releases/latest/download/yq_linux_amd64)
    printf '#!/usr/bin/env bash\necho "yq (v4) version v4.44.3"\n' >"\$out"; exit 0 ;;
esac
printf 'unexpected curl url: %s\n' "\$url" >&2
exit 1
EOF
run_module "$YQ" "$c"
assert_success "$RUN_RC" "installer exits 0"
assert_executable "$c/home/.local/bin/yq" "yq installed into LOCAL_BIN"
assert_contains "releases/latest/download/yq_linux_amd64" "$log" "downloaded the official asset"

# ---------------------------------------------------------------------------
describe "yq: already a v4 binary -> no download"
c="$(sandbox yq-idem)"
fb="$c/fakebin"; log="$c/work/curl.log"; : >"$log"
stub_uname "$fb"
stub "$fb" yq <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "--version" ]] && { echo "yq (https://github.com/mikefarah/yq/) version v4.44.3"; exit 0; }
exit 0
EOF
stub "$fb" curl <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$log"
exit 0
EOF
run_module "$YQ" "$c"
assert_success "$RUN_RC" "installer exits 0"
assert_contains "already installed" "$RUN_OUT" "reports already installed"
assert_empty "$log" "curl was not invoked"

harness_summary
