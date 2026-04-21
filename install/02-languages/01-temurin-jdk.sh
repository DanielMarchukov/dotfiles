#!/usr/bin/env bash
# =============================================================================
# install/02-languages/01-temurin-jdk.sh
#
# Installs Adoptium Temurin JDK 21 via APT. Adds the Adoptium APT
# repository on first run; re-runs are no-ops.
#
# First step of the JDK subchain:
#   01-temurin-jdk → 02-installcert-java → 05-gradle
# =============================================================================
set -euo pipefail

# Sourcing guard (dual-mode: works when sourced or executed)
if [[ -n "${_DOTFILES_TEMURIN_JDK_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_TEMURIN_JDK_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command sudo
require_command apt-get
require_command wget

TEMURIN_JAVA_HOME="/usr/lib/jvm/temurin-21-jdk-amd64"

info "Ensuring Temurin JDK 21 is installed..."
if ! dpkg-query -W -f='${Status}' temurin-21-jdk 2>/dev/null | grep -q "install ok installed"; then
    info "Adding Adoptium APT repository..."
    sudo mkdir -p /etc/apt/keyrings
    if [[ ! -f /etc/apt/keyrings/adoptium.gpg ]]; then
        wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public \
            | sudo gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg
    fi
    if [[ ! -f /etc/apt/sources.list.d/adoptium.list ]]; then
        echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME=/{print $2}' /etc/os-release) main" \
            | sudo tee /etc/apt/sources.list.d/adoptium.list > /dev/null
    fi
    sudo apt-get update -qq
fi
sudo apt-get install -y -qq temurin-21-jdk
ok "Temurin: $("$TEMURIN_JAVA_HOME/bin/java" -version 2>&1 | head -1)"
