#!/usr/bin/env bash
# =============================================================================
# install/02-languages/02-installcert-java.sh
#
# Optional step for corporate networks: runs InstallCert.java against
# $INSTALLCERT_HOST and merges the resulting certificates into Temurin's
# `cacerts` keystore. Required for Gradle to resolve HTTPS downloads
# behind a TLS-inspecting proxy.
#
# Gates on the presence of $INSTALLCERT_SOURCE — skips silently if the
# helper file isn't available, so this is a no-op on personal machines.
#
# Depends on 02-languages/01-temurin-jdk.sh (needs javac/java).
# Must run before 02-languages/05-gradle.sh on corporate networks.
# =============================================================================
set -euo pipefail

# Sourcing guard (dual-mode: works when sourced or executed)
if [[ -n "${_DOTFILES_INSTALLCERT_JAVA_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_INSTALLCERT_JAVA_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command sudo

INSTALLCERT_SOURCE="${INSTALLCERT_SOURCE:-/mnt/c/Users/$USER/Downloads/InstallCert.java}"
INSTALLCERT_HOST="${INSTALLCERT_HOST:-www.gradle.org}"
TEMURIN_JAVA_HOME="${TEMURIN_JAVA_HOME:-/usr/lib/jvm/temurin-21-jdk-amd64}"

info "Checking for optional InstallCert.java bootstrap..."
if [[ ! -f "$INSTALLCERT_SOURCE" ]]; then
    warn "InstallCert.java not found at $INSTALLCERT_SOURCE; skipping Java keystore certificate import"
    exit 0
fi

if [[ ! -x "$TEMURIN_JAVA_HOME/bin/java" || ! -x "$TEMURIN_JAVA_HOME/bin/javac" ]]; then
    warn "Temurin JDK tools not available under $TEMURIN_JAVA_HOME; skipping Java keystore certificate import"
    exit 0
fi

info "InstallCert.java found at $INSTALLCERT_SOURCE; attempting Java keystore certificate import for $INSTALLCERT_HOST"
INSTALLCERT_TMP_DIR=$(mktemp -d)
cp "$INSTALLCERT_SOURCE" "$INSTALLCERT_TMP_DIR/InstallCert.java"

if (
    cd "$INSTALLCERT_TMP_DIR"
    "$TEMURIN_JAVA_HOME/bin/javac" InstallCert.java
    "$TEMURIN_JAVA_HOME/bin/java" InstallCert --quiet "$INSTALLCERT_HOST"
); then
    if [[ -f "$INSTALLCERT_TMP_DIR/jssecacerts" ]]; then
        info "InstallCert generated jssecacerts; updating Temurin trust store"
        if [[ ! -f "$TEMURIN_JAVA_HOME/lib/security/cacerts-bak" ]]; then
            sudo cp "$TEMURIN_JAVA_HOME/lib/security/cacerts" "$TEMURIN_JAVA_HOME/lib/security/cacerts-bak"
            ok "Backed up existing cacerts to $TEMURIN_JAVA_HOME/lib/security/cacerts-bak"
        else
            info "Existing cacerts backup found at $TEMURIN_JAVA_HOME/lib/security/cacerts-bak"
        fi
        sudo cp "$INSTALLCERT_TMP_DIR/jssecacerts" "$TEMURIN_JAVA_HOME/lib/security/cacerts"
        ok "Updated Temurin cacerts using InstallCert output"
    else
        warn "InstallCert completed but did not produce jssecacerts; skipping keystore replacement"
    fi
else
    warn "InstallCert execution failed; skipping Java keystore certificate import"
fi

rm -rf "$INSTALLCERT_TMP_DIR"
