#!/usr/bin/env bash
# =============================================================================
# test/verify-nerd-font.sh
#
# install/06-shell/02-nerd-font.sh — the Windows-interop path. Under WSL the
# font must also land in the per-user Windows Fonts dir and be registered
# under HKCU. Everything the module shells out to (fc-list/curl/unzip,
# cmd.exe/wslpath/reg.exe) is stubbed, so the real interop logic runs with
# no network and no Windows host.
# =============================================================================
set -uo pipefail

if [[ -n "${_DOTFILES_VERIFY_NERD_FONT_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_VERIFY_NERD_FONT_SH_LOADED=1

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

describe "nerd-font: installs and registers the font on the Windows side under WSL"
c="$(sandbox nerd-font)"
fb="$c/fakebin"
font_dir="$c/home/.local/share/fonts"
win_localappdata="$c/windows-localappdata"
win_fonts_dir="$win_localappdata/Microsoft/Windows/Fonts"
proc_version="$c/proc-version"
reg_log="$c/reg.log"

mkdir -p "$font_dir" "$win_fonts_dir"
printf 'fake font data\n' >"$font_dir/0xProtoNerdFontMono-Regular.ttf"
printf 'Linux version 6.18.33.2-microsoft-standard-WSL2\n' >"$proc_version"

# fc-list reports the font present -> the Linux-side install is skipped and the
# pre-seeded .ttf above is what the Windows side copies.
stub "$fb" fc-list  <<'EOF'
#!/usr/bin/env bash
printf '0xProto Nerd Font Mono\n'
EOF
stub "$fb" fc-cache <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
stub "$fb" curl     <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
stub "$fb" unzip    <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
stub "$fb" cmd.exe  <<'EOF'
#!/usr/bin/env bash
printf 'C:\Fake\LocalAppData\r\n'
EOF

stub "$fb" wslpath <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "-w" ]]; then
  printf 'C:\\\\Fake\\\\LocalAppData\\\\Microsoft\\\\Windows\\\\Fonts\\\\%s\n' "\$(basename "\$2")"
  exit 0
fi
if [[ "\${1:-}" == 'C:\Fake\LocalAppData' ]]; then
  printf '%s\n' "$win_localappdata"
  exit 0
fi
printf 'unexpected wslpath args: %s\n' "\$*" >&2
exit 1
EOF

stub "$fb" reg.exe <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"$reg_log"
case "\${1:-}" in
  query) exit 1 ;;   # not yet registered
  add)   exit 0 ;;
esac
printf 'unexpected reg.exe args: %s\n' "\$*" >&2
exit 1
EOF

run_module "$ROOT_DIR/install/06-shell/02-nerd-font.sh" "$c" \
    PROC_VERSION_PATH="$proc_version" \
    WIN_CMD_EXE="$fb/cmd.exe" \
    WIN_REG_EXE="$fb/reg.exe"

assert_success "$RUN_RC" "installer exits 0 with interop stubs"
assert_file "$win_fonts_dir/0xProtoNerdFontMono-Regular.ttf" "font copied into Windows per-user Fonts dir"
assert_contains 'query HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts' "$reg_log" "queried the HKCU Fonts key"
assert_contains 'add HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts' "$reg_log" "registered under the HKCU Fonts key"

harness_summary
