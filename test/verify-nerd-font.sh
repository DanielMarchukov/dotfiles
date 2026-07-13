#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

case_dir="$TMPDIR/nerd-font"
fakebin="$case_dir/fakebin"
home_dir="$case_dir/home"
linux_font_dir="$home_dir/.local/share/fonts"
windows_localappdata="$case_dir/windows-localappdata"
windows_fonts_dir="$windows_localappdata/Microsoft/Windows/Fonts"
proc_version_file="$case_dir/proc-version"
reg_log="$case_dir/reg.log"
stdout="$case_dir/stdout"
stderr="$case_dir/stderr"

mkdir -p "$fakebin" "$linux_font_dir" "$windows_fonts_dir"
printf 'Linux version 6.18.33.2-microsoft-standard-WSL2\n' >"$proc_version_file"
printf 'fake font data\n' >"$linux_font_dir/0xProtoNerdFontMono-Regular.ttf"

cat >"$fakebin/fc-list" <<'EOF'
#!/usr/bin/env bash
printf '0xProto Nerd Font Mono\n'
EOF
chmod +x "$fakebin/fc-list"

cat >"$fakebin/fc-cache" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$fakebin/fc-cache"

cat >"$fakebin/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$fakebin/curl"

cat >"$fakebin/unzip" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$fakebin/unzip"

cat >"$fakebin/cmd.exe" <<'EOF'
#!/usr/bin/env bash
printf 'C:\Fake\LocalAppData\r\n'
EOF
chmod +x "$fakebin/cmd.exe"

cat >"$fakebin/wslpath" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "-w" ]]; then
  printf 'C:\\Fake\\LocalAppData\\Microsoft\\Windows\\Fonts\\%s\n' "\$(basename "\$2")"
  exit 0
fi

if [[ "\${1:-}" == 'C:\Fake\LocalAppData' ]]; then
  printf '%s\n' "$windows_localappdata"
  exit 0
fi

printf 'unexpected wslpath args: %s\n' "\$*" >&2
exit 1
EOF
chmod +x "$fakebin/wslpath"

cat >"$fakebin/reg.exe" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"$reg_log"
if [[ "\${1:-}" == "query" ]]; then
  exit 1
fi
if [[ "\${1:-}" == "add" ]]; then
  exit 0
fi
printf 'unexpected reg.exe args: %s\n' "\$*" >&2
exit 1
EOF
chmod +x "$fakebin/reg.exe"

HOME="$home_dir" \
PATH="$fakebin:/usr/bin:/bin" \
PROC_VERSION_PATH="$proc_version_file" \
WIN_CMD_EXE="$fakebin/cmd.exe" \
WIN_REG_EXE="$fakebin/reg.exe" \
bash "$ROOT_DIR/install/06-shell/02-nerd-font.sh" >"$stdout" 2>"$stderr" || {
  printf 'FAIL: 02-nerd-font.sh should succeed when Windows executables are provided explicitly outside PATH lookup assumptions\n' >&2
  cat "$stdout" >&2 || true
  cat "$stderr" >&2 || true
  exit 1
}

if [[ ! -f "$windows_fonts_dir/0xProtoNerdFontMono-Regular.ttf" ]]; then
  printf 'FAIL: expected font copied into Windows per-user Fonts directory\n' >&2
  find "$windows_localappdata" -maxdepth 4 -type f | sort >&2 || true
  cat "$stdout" >&2 || true
  cat "$stderr" >&2 || true
  exit 1
fi

if ! grep -q 'query HKCU\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts' "$reg_log"; then
  printf 'FAIL: expected registry query against Windows Fonts key\n' >&2
  cat "$reg_log" >&2 || true
  exit 1
fi

if ! grep -q 'add HKCU\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts' "$reg_log"; then
  printf 'FAIL: expected registry add against Windows Fonts key\n' >&2
  cat "$reg_log" >&2 || true
  exit 1
fi
