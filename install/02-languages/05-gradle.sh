#!/usr/bin/env bash
# =============================================================================
# install/02-languages/05-gradle.sh
#
# Installs Gradle at a pinned version (overridable via $GRADLE_VERSION).
# Downloads the distribution zip, extracts to /opt, and symlinks the
# binary to /usr/local/bin/gradle.
#
# Reinstalls if the currently-active gradle reports a different version
# (matches the version-pin check from bootstrap.sh).
#
# Third step of the JDK subchain:
#   01-temurin-jdk → 02-installcert-java → 05-gradle
# On corporate networks, 02-installcert-java must already have imported
# the TLS-inspecting proxy cert before Gradle's first HTTPS fetch.
# =============================================================================
set -euo pipefail

# Sourcing guard (dual-mode: works when sourced or executed)
if [[ -n "${_DOTFILES_GRADLE_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_GRADLE_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command sudo
require_command curl
require_command unzip

GRADLE_VERSION="${GRADLE_VERSION:-8.11.1}"

if ! command -v gradle &>/dev/null || [[ "$(gradle --version 2>/dev/null | awk '/^Gradle /{print $2; exit}')" != "$GRADLE_VERSION" ]]; then
    info "Installing Gradle ${GRADLE_VERSION}..."
    GRADLE_ZIP="/tmp/gradle-${GRADLE_VERSION}-bin.zip"
    curl -fsSL -o "$GRADLE_ZIP" "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip"
    sudo rm -rf "/opt/gradle-${GRADLE_VERSION}"
    sudo unzip -q -o "$GRADLE_ZIP" -d /opt
    sudo ln -sf "/opt/gradle-${GRADLE_VERSION}/bin/gradle" /usr/local/bin/gradle
    rm -f "$GRADLE_ZIP"
    ok "Gradle: $(gradle --version | awk '/^Gradle /{print $2; exit}')"
else
    ok "Gradle: $(gradle --version | awk '/^Gradle /{print $2; exit}')"
fi
