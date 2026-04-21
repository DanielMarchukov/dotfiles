#!/usr/bin/env bash
# =============================================================================
# Dotfiles Bootstrap Script
# Sets up a fresh Linux machine with all dotfiles, tools, and configs.
# Fully idempotent — safe to re-run at any time to fix/update.
# Usage: curl -fsSL <raw-url> | bash   OR   ./bootstrap.sh
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[0;32m[ OK ]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }
err()   { printf '\033[0;31m[ ERR]\033[0m  %s\n' "$*" >&2; }

DOTFILES_REPO="https://github.com/DanielMarchukov/dotfiles.git"
DOTFILES_DIR="$HOME/repos/dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
BACKUP_NEEDED=false
OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
LEGACY_OH_MY_ZSH_DIR="$DOTFILES_DIR/.oh-my-zsh"
TPM_DIR="$HOME/.tmux/plugins/tpm"
LEGACY_TPM_DIR="$DOTFILES_DIR/.tmux/plugins/tpm"
TEMURIN_JAVA_HOME="/usr/lib/jvm/temurin-21-jdk-amd64"
GRADLE_VERSION="${GRADLE_VERSION:-8.11.1}"
INSTALLCERT_SOURCE="${INSTALLCERT_SOURCE:-/mnt/c/Users/$USER/Downloads/InstallCert.java}"
INSTALLCERT_HOST="${INSTALLCERT_HOST:-www.gradle.org}"

backup_if_real() {
    # Back up a file/dir only if it exists and is NOT already a symlink
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
        if [[ "$BACKUP_NEEDED" == false ]]; then
            mkdir -p "$BACKUP_DIR"
            BACKUP_NEEDED=true
        fi
        mv "$target" "$BACKUP_DIR/"
        info "Backed up $target"
    elif [[ -L "$target" ]]; then
        # Remove stale symlink so stow/ln can recreate it
        rm -f "$target"
    fi
}

remove_legacy_repo_absolute_symlink() {
    local target="$1"
    local link_target

    if [[ ! -L "$target" ]]; then
        return 0
    fi

    link_target="$(readlink "$target" 2>/dev/null || true)"
    if [[ "$link_target" == "$DOTFILES_DIR/"* ]]; then
        rm -f "$target"
        info "Removed legacy repo symlink $target -> $link_target"
    fi
}

runtime_path_is_legacy_symlink() {
    local runtime_path="$1"
    local legacy_path="$2"
    local resolved_path

    if [[ ! -L "$runtime_path" ]]; then
        return 1
    fi

    resolved_path="$(readlink -f "$runtime_path" 2>/dev/null || true)"
    [[ "$resolved_path" == "$legacy_path" ]]
}

ensure_runtime_git_checkout() {
    local label="$1"
    local runtime_path="$2"
    local legacy_path="$3"
    local repo_url="$4"

    mkdir -p "$(dirname "$runtime_path")"

    if runtime_path_is_legacy_symlink "$runtime_path" "$legacy_path"; then
        rm -f "$runtime_path"
        if [[ -d "$legacy_path" ]]; then
            mv "$legacy_path" "$runtime_path"
            ok "Migrated $label from repo checkout to $runtime_path"
            return 0
        fi
    fi

    if [[ ! -e "$runtime_path" && -d "$legacy_path" ]]; then
        mv "$legacy_path" "$runtime_path"
        ok "Migrated $label from repo checkout to $runtime_path"
        return 0
    fi

    if [[ -d "$runtime_path/.git" ]]; then
        ok "$label already installed"
        return 0
    fi

    if [[ ! -e "$runtime_path" ]]; then
        info "Installing $label..."
        git clone --depth=1 "$repo_url" "$runtime_path"
        ok "$label installed"
    else
        warn "$label path $runtime_path exists but is not a git checkout; leaving it untouched"
    fi
}

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
# 1. System packages (apt-get install is already idempotent)
# ---------------------------------------------------------------------------
info "Ensuring system packages are installed..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    zsh git curl wget stow tmux \
    fd-find bat ripgrep zoxide \
    python3 pipx \
    build-essential cmake \
    unzip fontconfig \
    sqlite3 \
    jq \
    uuid-dev libgnutls28-dev

# fd is packaged as 'fdfind' on Ubuntu — create symlink if needed
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

# bat is packaged as 'batcat' on Ubuntu — create symlink if needed
if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
fi

ok "System packages"

# ---------------------------------------------------------------------------
# 1b. Temurin JDK 21
# ---------------------------------------------------------------------------
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
ok "Temurin: $(/usr/lib/jvm/temurin-21-jdk-amd64/bin/java -version 2>&1 | head -1)"

# ---------------------------------------------------------------------------
# 1c. Optional corporate certificate import for Gradle/Java
# ---------------------------------------------------------------------------
info "Checking for optional InstallCert.java bootstrap..."
if [[ ! -f "$INSTALLCERT_SOURCE" ]]; then
    warn "InstallCert.java not found at $INSTALLCERT_SOURCE; skipping Java keystore certificate import"
elif [[ ! -x "$TEMURIN_JAVA_HOME/bin/java" || ! -x "$TEMURIN_JAVA_HOME/bin/javac" ]]; then
    warn "Temurin JDK tools not available under $TEMURIN_JAVA_HOME; skipping Java keystore certificate import"
else
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
fi

# ---------------------------------------------------------------------------
# 1d. Go
# ---------------------------------------------------------------------------
if ! command -v go &>/dev/null; then
    info "Installing Go..."
    GO_VERSION=$(curl -fsSL https://go.dev/dl/?mode=json | jq -r '.[0].version')
    GO_TARBALL="${GO_VERSION}.linux-amd64.tar.gz"
    curl -fsSL -o "/tmp/${GO_TARBALL}" "https://go.dev/dl/${GO_TARBALL}"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "/tmp/${GO_TARBALL}"
    rm -f "/tmp/${GO_TARBALL}"
    ok "Go: $(/usr/local/go/bin/go version)"
else
    ok "Go: $(go version)"
fi

if ! command -v gopls &>/dev/null; then
    info "Installing gopls..."
    /usr/local/go/bin/go install golang.org/x/tools/gopls@latest
    ok "gopls installed"
else
    ok "gopls: $(gopls version | head -1)"
fi

# ---------------------------------------------------------------------------
# 1e. fzf (from git — apt version is too old for oh-my-zsh fzf plugin)
# ---------------------------------------------------------------------------
if [[ ! -d "$HOME/.fzf" ]]; then
    info "Installing fzf from git..."
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --bin --no-bash --no-fish --no-update-rc
    ok "fzf installed: $("$HOME/.fzf/bin/fzf" --version)"
elif [[ -d "$HOME/.fzf/.git" ]]; then
    info "Updating fzf..."
    git -C "$HOME/.fzf" pull --ff-only 2>/dev/null && "$HOME/.fzf/install" --bin --no-bash --no-fish --no-update-rc 2>/dev/null || true
    ok "fzf: $("$HOME/.fzf/bin/fzf" --version)"
fi
export PATH="$HOME/.fzf/bin:$PATH"

# Ensure pipx path is available for tool installs below
pipx ensurepath 2>/dev/null || true
export PATH="$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------------------
# 2. C++ development toolchain
# ---------------------------------------------------------------------------
info "Ensuring C++ toolchain is installed..."

# LLVM/Clang 19 APT repo
if ! command -v clang-19 &>/dev/null; then
    info "Adding LLVM 19 APT repository..."
    wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | sudo tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc > /dev/null
    CODENAME=$(lsb_release -cs)
    echo "deb http://apt.llvm.org/$CODENAME/ llvm-toolchain-$CODENAME-19 main" \
        | sudo tee /etc/apt/sources.list.d/llvm-19.list > /dev/null
    sudo apt-get update -qq
fi

sudo apt-get install -y -qq \
    g++-14 libstdc++-14-dev \
    clang-19 clang-format-19 clang-tidy-19 llvm-19 \
    ninja-build pkg-config \
    autoconf automake autoconf-archive libtool \
    linux-libc-dev lcov \
    libboost-all-dev libzmq3-dev libcurl4-openssl-dev libssl-dev

# Symlink clang-19 as default if no unversioned clang exists
if command -v clang-19 &>/dev/null && ! command -v clang &>/dev/null; then
    sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-19 100
    sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-19 100
    sudo update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-19 100
    sudo update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-19 100
fi

ok "C++ toolchain"

# vcpkg
export VCPKG_ROOT="$HOME/vcpkg"
if [[ ! -d "$VCPKG_ROOT" ]]; then
    info "Installing vcpkg..."
    git clone https://github.com/microsoft/vcpkg.git "$VCPKG_ROOT"
    "$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics
    ok "vcpkg installed"
elif [[ -d "$VCPKG_ROOT/.git" ]]; then
    info "Updating vcpkg..."
    git -C "$VCPKG_ROOT" pull --ff-only 2>/dev/null && "$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics 2>/dev/null || true
    ok "vcpkg: up to date"
fi
export PATH="$VCPKG_ROOT:$PATH"

# pre-commit (for C++ projects that use it)
if ! command -v pre-commit &>/dev/null; then
    info "Installing pre-commit via pipx..."
    pipx install pre-commit 2>/dev/null \
        || warn "pre-commit install failed (non-fatal)"
else
    ok "pre-commit: $(pre-commit --version)"
fi

# cmake-format (part of cmakelang package) and mdformat (used by pre-commit hooks)
if ! command -v cmake-format &>/dev/null; then
    info "Installing cmakelang (cmake-format) via pipx..."
    pipx install cmakelang 2>/dev/null || warn "cmakelang install failed (non-fatal)"
else
    ok "cmake-format already installed"
fi

if ! command -v mdformat &>/dev/null; then
    info "Installing mdformat via pipx..."
    pipx install mdformat 2>/dev/null || warn "mdformat install failed (non-fatal)"
else
    ok "mdformat already installed"
fi

# ---------------------------------------------------------------------------
# 3. GitHub CLI
# ---------------------------------------------------------------------------
if ! command -v gh &>/dev/null; then
    info "Installing GitHub CLI..."
    sudo mkdir -p -m 755 /etc/apt/keyrings
    out=$(mktemp)
    wget -nv -O "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg
    cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install gh -y -qq
    rm -f "$out"
    ok "GitHub CLI installed"
else
    ok "GitHub CLI: $(gh --version | head -1)"
fi

# ---------------------------------------------------------------------------
# 3. Neovim (latest stable via GitHub release)
# ---------------------------------------------------------------------------
if ! command -v nvim &>/dev/null; then
    info "Installing Neovim..."
    NVIM_VERSION=$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest | jq -r '.tag_name')
    curl -fsSL -o /tmp/nvim-linux-x86_64.tar.gz \
        "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"
    sudo rm -rf /opt/nvim-linux-x86_64
    sudo tar xzf /tmp/nvim-linux-x86_64.tar.gz -C /opt/
    sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
    rm -f /tmp/nvim-linux-x86_64.tar.gz
    ok "Neovim ${NVIM_VERSION} installed"
else
    ok "Neovim: $(nvim --version | head -1)"
fi

# ---------------------------------------------------------------------------
# 4. Gradle
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# 5. Palantir Java Format
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

# ---------------------------------------------------------------------------
# 6. Rust toolchain (via rustup — official installer)
# ---------------------------------------------------------------------------
if ! command -v rustup &>/dev/null; then
    info "Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --quiet
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"
    ok "Rust installed: $(rustc --version)"
else
    # Ensure toolchain is up to date
    rustup update stable --no-self-update 2>/dev/null || true
    ok "Rust: $(rustc --version)"
fi

# Ensure standard components are installed
rustup component add clippy rustfmt llvm-tools-preview 2>/dev/null || true

# Cargo dev tools (used by tusk and rop CI pipelines)
CARGO_TOOLS=(
    "cargo-llvm-cov"    # code coverage
    "cargo-audit"       # security vulnerability audit
    "cargo-deny"        # dependency license/source linting
)

for tool in "${CARGO_TOOLS[@]}"; do
    bin_name="${tool}"
    if ! cargo install --list 2>/dev/null | grep -q "^${tool} "; then
        info "Installing ${tool}..."
        cargo install "${tool}" --quiet 2>/dev/null \
            || warn "${tool} install failed (non-fatal)"
    else
        ok "cargo tool: ${tool}"
    fi
done

# ---------------------------------------------------------------------------
# 7. NVM + Node.js
# ---------------------------------------------------------------------------
export NVM_DIR="$HOME/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
    info "Installing NVM..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    info "Installing latest LTS Node.js..."
    nvm install --lts
    nvm alias default 'lts/*'
    ok "Node.js installed: $(node --version)"
else
    ok "NVM already installed"
fi

# ---------------------------------------------------------------------------
# 8. pay-respects (thefuck replacement — thefuck is broken on Python 3.12+)
# ---------------------------------------------------------------------------
if ! command -v pay-respects &>/dev/null; then
    info "Installing pay-respects via cargo..."
    cargo install pay-respects --quiet 2>/dev/null \
        || warn "pay-respects install failed (non-fatal, install manually with: cargo install pay-respects)"
else
    ok "pay-respects: $(pay-respects --version 2>&1 | head -1)"
fi

# Clean up legacy thefuck pipx install if present (distutils/imp removed in Py3.12)
if command -v pipx &>/dev/null && pipx list --short 2>/dev/null | grep -q '^thefuck '; then
    info "Removing legacy thefuck pipx install..."
    pipx uninstall thefuck >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# 9. Prepare dotfiles repo
# ---------------------------------------------------------------------------
if [[ -d "$DOTFILES_DIR/.git" ]]; then
    info "Using local dotfiles repo at $DOTFILES_DIR"
elif [[ -d "$HOME/repos/.git" ]]; then
    err "Expected dotfiles repo at $DOTFILES_DIR but found a git repo at $HOME/repos instead"
    err "Move or clone the dotfiles repo to $DOTFILES_DIR and re-run bootstrap"
    exit 1
else
    info "Cloning dotfiles repo into $DOTFILES_DIR..."
    mkdir -p "$(dirname "$DOTFILES_DIR")"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# Init core submodules — always runs (idempotent, skips already-init'd)
info "Syncing submodules..."
git -C "$DOTFILES_DIR" submodule update --init .config

# Init nvim inside .config submodule
if [[ -f "$DOTFILES_DIR/.config/.gitmodules" ]]; then
    git -C "$DOTFILES_DIR/.config" submodule update --init nvim 2>/dev/null || true
fi

ok "Dotfiles repo ready"

# ---------------------------------------------------------------------------
# 10. Runtime dependency checkouts
# ---------------------------------------------------------------------------
ensure_runtime_git_checkout "oh-my-zsh" "$OH_MY_ZSH_DIR" "$LEGACY_OH_MY_ZSH_DIR" \
    "https://github.com/ohmyzsh/ohmyzsh.git"
ensure_runtime_git_checkout "Tmux Plugin Manager" "$TPM_DIR" "$LEGACY_TPM_DIR" \
    "https://github.com/tmux-plugins/tpm.git"

# ---------------------------------------------------------------------------
# 11. Powerlevel10k theme
# ---------------------------------------------------------------------------
P10K_DIR="$OH_MY_ZSH_DIR/custom/themes/powerlevel10k"
if [[ ! -d "$P10K_DIR" ]]; then
    info "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    ok "Powerlevel10k installed"
else
    ok "Powerlevel10k already installed"
fi

# ---------------------------------------------------------------------------
# 12. Oh-My-Zsh custom plugins
# ---------------------------------------------------------------------------
ZSH_CUSTOM="$OH_MY_ZSH_DIR/custom"

declare -A PLUGINS=(
    [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions.git"
    [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
    [fzf-z]="https://github.com/andrewferrier/fzf-z.git"
    [you-should-use]="https://github.com/MichaelAquilina/zsh-you-should-use.git"
    [zsh-bat]="https://github.com/fdellwing/zsh-bat.git"
)

for plugin in "${!PLUGINS[@]}"; do
    dest="$ZSH_CUSTOM/plugins/$plugin"
    if [[ ! -d "$dest" ]]; then
        info "Installing zsh plugin: $plugin"
        git clone --depth=1 "${PLUGINS[$plugin]}" "$dest"
    else
        ok "zsh plugin: $plugin"
    fi
done

# ---------------------------------------------------------------------------
# 12. Back up conflicting dotfiles and stow
# ---------------------------------------------------------------------------
# Top-level files stow will manage
STOW_FILES=(
    .zshrc .zshenv .zprofile .profile .bash_profile
    .p10k.zsh .gitignore_global .gitmodules
)

for f in "${STOW_FILES[@]}"; do
    backup_if_real "$HOME/$f"
done

# Refuse to proceed if ~/.config is a wholesale symlink to the submodule:
# CONFIG_ITEMS below would resolve through the link and wipe submodule
# contents via backup_if_real. Per-item symlinks only.
if [[ -L "$HOME/.config" ]]; then
    config_target="$(readlink -f "$HOME/.config" 2>/dev/null || true)"
    if [[ "$config_target" == "$DOTFILES_DIR/.config" ]]; then
        err "~/.config is a wholesale symlink to $DOTFILES_DIR/.config."
        err "Migrate to per-item symlinks before re-running:"
        err "  rm ~/.config && mkdir ~/.config"
        err "  mv $DOTFILES_DIR/.config/{atuin,gh,github-copilot,glab-cli,go} ~/.config/ 2>/dev/null || true"
        exit 1
    fi
fi

# .config items managed individually (don't replace the whole .config dir)
mkdir -p "$HOME/.config"
CONFIG_ITEMS=(nvim tmux git just tealdeer)
for item in "${CONFIG_ITEMS[@]}"; do
    backup_if_real "$HOME/.config/$item"
done

# .github items are managed individually so Copilot/global GitHub state can
# coexist with other files under ~/.github without replacing the whole dir.
if [[ -d "$DOTFILES_DIR/.github" ]]; then
    mkdir -p "$HOME/.github"
    while IFS= read -r repo_github_file; do
        rel_path="${repo_github_file#"$DOTFILES_DIR/.github/"}"
        target_path="$HOME/.github/$rel_path"
        mkdir -p "$(dirname "$target_path")"
        backup_if_real "$target_path"
    done < <(find "$DOTFILES_DIR/.github" -type f | sort)
fi

# Items managed outside of stow — drop stale symlinks so stow's restow scan
# doesn't trip on absolute symlinks pointing back into the stow dir.
backup_if_real "$HOME/.taskrc"

# Legacy hand-made links inside real directories confuse stow: they point into
# the repo, but because they're absolute, stow won't treat them as owned links.
if [[ -d "$HOME/bin" && -d "$DOTFILES_DIR/bin" ]]; then
    shopt -s nullglob
    for repo_bin_item in "$DOTFILES_DIR"/bin/*; do
        remove_legacy_repo_absolute_symlink "$HOME/bin/$(basename "$repo_bin_item")"
    done
    shopt -u nullglob
fi

if [[ "$BACKUP_NEEDED" == true ]]; then
    ok "Backups saved to $BACKUP_DIR"
fi

# Stow top-level dotfiles (--restow is idempotent — re-links if already stowed)
# Use the repo parent as the stow dir so restow recreates relative links back
# into ../repos/... after the legacy absolute-link cleanup above.
info "Stowing dotfiles..."
stow --restow \
    -d "$(dirname "$DOTFILES_DIR")" \
    -t "$HOME" \
    --ignore='\.config' \
    --ignore='\.github' \
    --ignore='\.claude' \
    --ignore='\.local' \
    --ignore='\.oh-my-zsh' \
    --ignore='\.tmux' \
    --ignore='\.git' \
    --ignore='\.gitconfig' \
    --ignore='\.gitignore' \
    --ignore='\.codex' \
    --ignore='\.taskrc' \
    --ignore='windows' \
    --ignore='install' \
    --ignore='bootstrap\.sh' \
    --ignore='install-cli-extensions\.sh' \
    --ignore='install-mcp\.sh' \
    --ignore='README.*' \
    "$(basename "$DOTFILES_DIR")"

# Symlink .config items individually (ln -sfn is idempotent)
for item in "${CONFIG_ITEMS[@]}"; do
    if [[ -d "$DOTFILES_DIR/.config/$item" ]]; then
        ln -sfn "$DOTFILES_DIR/.config/$item" "$HOME/.config/$item"
        ok "Linked ~/.config/$item"
    fi
done

if [[ -d "$DOTFILES_DIR/.github" ]]; then
    while IFS= read -r repo_github_file; do
        rel_path="${repo_github_file#"$DOTFILES_DIR/.github/"}"
        target_path="$HOME/.github/$rel_path"
        ln -sfn "$repo_github_file" "$target_path"
        ok "Linked ~/.github/$rel_path"
    done < <(find "$DOTFILES_DIR/.github" -type f | sort)
fi

ok "Dotfiles stowed"

# ---------------------------------------------------------------------------
# 12b. Shell workflow extensions
# ---------------------------------------------------------------------------
if [[ "${SKIP_CLI_EXTENSIONS:-0}" == "1" ]]; then
    warn "Skipping install-cli-extensions.sh because SKIP_CLI_EXTENSIONS=1"
elif [[ -x "$DOTFILES_DIR/install-cli-extensions.sh" ]]; then
    info "Installing shell CLI extensions..."
    "$DOTFILES_DIR/install-cli-extensions.sh"
else
    warn "install-cli-extensions.sh not found or not executable; skipping shell CLI extensions"
fi

# ---------------------------------------------------------------------------
# 13. Fix hardcoded paths — make dotfiles portable
# ---------------------------------------------------------------------------
# Replace hardcoded /home/danmarchukov/ with actual $HOME in files that need it.
# Uses grep guard so it's a no-op on re-run (already patched = no match).
patch_home() {
    local file="$1"
    if [[ -f "$file" ]] && grep -q '/home/danmarchukov/' "$file" 2>/dev/null; then
        sed -i "s|/home/danmarchukov/|$HOME/|g" "$file"
        ok "Patched paths in $(basename "$file")"
    fi
}

patch_home "$DOTFILES_DIR/.zshenv"
patch_home "$DOTFILES_DIR/.zprofile"

# ---------------------------------------------------------------------------
# 14. Install tmux plugins via TPM
# ---------------------------------------------------------------------------
TPM_INSTALL="$HOME/.tmux/plugins/tpm/bin/install_plugins"
if [[ -x "$TPM_INSTALL" ]]; then
    info "Installing tmux plugins via TPM..."
    "$TPM_INSTALL" 2>/dev/null && ok "Tmux plugins installed" \
        || warn "TPM install failed (start tmux and press prefix+I)"
else
    warn "TPM not found — tmux plugins will install on first tmux launch (prefix+I)"
fi

# ---------------------------------------------------------------------------
# 15. Set zsh as default shell
# ---------------------------------------------------------------------------
if [[ "$SHELL" != *"zsh"* ]]; then
    info "Changing default shell to zsh..."
    chsh -s "$(command -v zsh)" || warn "Could not change shell (run: chsh -s $(command -v zsh))"
else
    ok "Default shell is already zsh"
fi

# ---------------------------------------------------------------------------
# 16. Install Nerd Font (for Powerlevel10k icons)
# ---------------------------------------------------------------------------
FONT_DIR="$HOME/.local/share/fonts"
if ! fc-list 2>/dev/null | grep -qi "MesloLGS"; then
    info "Installing MesloLGS Nerd Font..."
    mkdir -p "$FONT_DIR"
    FONT_BASE="https://github.com/romkatv/powerlevel10k-media/raw/master"
    for variant in "Regular" "Bold" "Italic" "Bold%20Italic"; do
        name="${variant//%20/ }"
        curl -fsSL -o "$FONT_DIR/MesloLGS NF ${name}.ttf" \
            "${FONT_BASE}/MesloLGS%20NF%20${variant}.ttf"
    done
    fc-cache -f "$FONT_DIR"
    ok "MesloLGS Nerd Font installed"
else
    ok "MesloLGS Nerd Font already installed"
fi

# ---------------------------------------------------------------------------
# 17. Neovim plugin sync (headless)
# ---------------------------------------------------------------------------
if command -v nvim &>/dev/null; then
    info "Syncing Neovim plugins (lazy.nvim)..."
    nvim --headless "+Lazy! sync" +qa 2>/dev/null && ok "Neovim plugins synced" \
        || warn "Neovim plugin sync failed (open nvim manually to complete setup)"

    info "Updating Mason tool registry..."
    nvim --headless -c "lua require('mason-registry').refresh()" -c "sleep 5" -c "qa" 2>/dev/null \
        && ok "Mason registry updated" \
        || warn "Mason update failed (open nvim manually, tools install on first use)"

    info "Installing Mason Java tooling..."
    nvim --headless "+MasonInstall jdtls java-debug-adapter java-test" +qa 2>/dev/null \
        && ok "Mason Java tools installed" \
        || warn "Mason Java tool install failed (open a Java file in nvim to trigger install)"
fi

# ---------------------------------------------------------------------------
# 18. Taskwarrior 3.x (built from source — apt only ships 2.x)
# ---------------------------------------------------------------------------
TW_MIN_VERSION="3"
install_taskwarrior=false

if ! command -v task &>/dev/null; then
    install_taskwarrior=true
elif [[ "$(task --version 2>/dev/null | cut -d. -f1)" -lt "$TW_MIN_VERSION" ]]; then
    info "Taskwarrior $(task --version) found but < 3.x, upgrading..."
    install_taskwarrior=true
fi

if [[ "$install_taskwarrior" == true ]]; then
    info "Building Taskwarrior 3.x from source..."
    if TW_VERSION=$(curl -fsSL https://api.github.com/repos/GothenburgBitFactory/taskwarrior/releases/latest | jq -r '.tag_name' | sed 's/^v//'); then
        TW_BUILD_DIR=$(mktemp -d)
        if curl -fsSL -o "$TW_BUILD_DIR/task.tar.gz" \
            "https://github.com/GothenburgBitFactory/taskwarrior/releases/download/v${TW_VERSION}/task-${TW_VERSION}.tar.gz" \
            && tar xzf "$TW_BUILD_DIR/task.tar.gz" -C "$TW_BUILD_DIR" \
            && cmake -S "$TW_BUILD_DIR/task-${TW_VERSION}" -B "$TW_BUILD_DIR/build" \
                -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
            && cmake --build "$TW_BUILD_DIR/build" -j"$(nproc)" \
            && sudo cmake --install "$TW_BUILD_DIR/build"; then
            ok "Taskwarrior ${TW_VERSION} installed"
        else
            warn "Taskwarrior build failed; continuing without Taskwarrior 3.x"
        fi
        rm -rf "$TW_BUILD_DIR"
    else
        warn "Could not resolve latest Taskwarrior release; continuing without Taskwarrior 3.x"
    fi
else
    ok "Taskwarrior: $(task --version)"
fi

# Symlink .taskrc from dotfiles
if [[ -f "$DOTFILES_DIR/.taskrc" ]]; then
    backup_if_real "$HOME/.taskrc"
    ln -sf "$DOTFILES_DIR/.taskrc" "$HOME/.taskrc"
    ok "Linked ~/.taskrc"
fi

# Patch hardcoded home path in .taskrc
patch_home "$DOTFILES_DIR/.taskrc"

# ---------------------------------------------------------------------------
# 19. Claude Code MCP servers (uv + basic-memory + git + context7)
# ---------------------------------------------------------------------------
if [[ "${SKIP_MCP:-0}" == "1" ]]; then
    warn "Skipping install-mcp.sh because SKIP_MCP=1"
elif [[ -x "$DOTFILES_DIR/install-mcp.sh" ]]; then
    info "Installing Claude Code MCP servers..."
    "$DOTFILES_DIR/install-mcp.sh"
else
    warn "install-mcp.sh not found or not executable; skipping MCP setup"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo
ok "Bootstrap complete!"
echo
info "Next steps:"
info "  1. Log out and back in (or run: exec zsh)"
info "  2. Set your terminal font to 'MesloLGS NF'"
info "  3. Run 'gh auth login' to authenticate GitHub CLI"
info "  4. Per project: run 'basic-memory project add <name> .' to init memory vault"
info "     (Set CONTEXT7_API_KEY in ~/.config/secrets/mcp.env to enable context7 MCP)"
if [[ "$BACKUP_NEEDED" == true ]]; then
    info "  5. Old dotfiles backed up to: $BACKUP_DIR"
fi
info "  Optional: install Go as needed"
echo
