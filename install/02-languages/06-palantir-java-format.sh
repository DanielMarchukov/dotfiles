#!/usr/bin/env bash
# =============================================================================
# install/02-languages/06-palantir-java-format.sh
#
# Installs palantir-java-format-native as a standalone binary at
# $HOME/.local/bin/palantir-java-format. Fetches the latest release
# from Maven Central and picks the platform-specific native image.
#
# This is a native binary — does NOT require the JDK at install time
# (despite the name). Independent of the JDK subchain within this
# bucket.
# =============================================================================
set -euo pipefail

# Sourcing guard (dual-mode: works when sourced or executed)
if [[ -n "${_DOTFILES_PALANTIR_JAVA_FORMAT_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_PALANTIR_JAVA_FORMAT_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command curl
require_command awk

# ---------------------------------------------------------------------------
# Helpers (palantir-specific; kept local rather than in lib/)
# ---------------------------------------------------------------------------
palantir_java_format_is_healthy() {
    command -v palantir-java-format &>/dev/null \
        && palantir-java-format --version >/dev/null 2>&1
}

palantir_java_format_native_suffix() {
    case "$(uname -s):$(uname -m)" in
        Linux:x86_64|Linux:amd64)
            printf '%s' 'nativeImage-linux-glibc_x86-64.bin'
            ;;
        Linux:aarch64|Linux:arm64)
            printf '%s' 'nativeImage-linux-glibc_aarch64.bin'
            ;;
        Darwin:aarch64|Darwin:arm64)
            printf '%s' 'nativeImage-macos_aarch64.bin'
            ;;
        *)
            return 1
            ;;
    esac
}

install_palantir_java_format() {
    local version native_suffix launcher_path version_output

    launcher_path="$HOME/.local/bin/palantir-java-format"
    mkdir -p "$HOME/.local/bin"

    native_suffix="$(palantir_java_format_native_suffix)" || {
        err "Unsupported palantir-java-format-native platform: $(uname -s) $(uname -m)"
        return 1
    }

    version=$(curl -fsSL 'https://repo1.maven.org/maven2/com/palantir/javaformat/palantir-java-format-native/maven-metadata.xml' \
        | awk -F'[<>]' '/<release>/{print $3; exit}')

    curl -fsSL -o "$launcher_path" \
        "https://repo1.maven.org/maven2/com/palantir/javaformat/palantir-java-format-native/${version}/palantir-java-format-native-${version}-${native_suffix}"
    chmod +x "$launcher_path"

    if ! "$launcher_path" --version >/dev/null 2>&1; then
        err "Installed palantir-java-format-native binary is not executable"
        return 1
    fi

    version_output=$("$launcher_path" --version 2>&1 | head -1)
    ok "palantir-java-format: ${version_output:-$version}"
}

# ---------------------------------------------------------------------------
# Install / reinstall
# ---------------------------------------------------------------------------
if ! palantir_java_format_is_healthy; then
    if command -v palantir-java-format &>/dev/null; then
        warn "Existing palantir-java-format install is unhealthy; reinstalling"
    else
        info "Installing palantir-java-format..."
    fi
    install_palantir_java_format
else
    ok "palantir-java-format: $(palantir-java-format --version 2>&1 | head -1)"
fi
