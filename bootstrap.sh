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
DOTFILES_DIR="$HOME/Documents/projects/dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
BACKUP_NEEDED=false

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
    jq

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
# 1b. fzf (from git — apt version is too old for oh-my-zsh fzf plugin)
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
# 4. Rust toolchain (via rustup — official installer)
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
# 5. NVM + Node.js
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
# 6. pipx + thefuck
# ---------------------------------------------------------------------------
if ! command -v thefuck &>/dev/null; then
    info "Installing thefuck via pipx..."
    pipx install thefuck 2>/dev/null \
        || warn "thefuck install failed (non-fatal, install manually with: pipx install thefuck)"
else
    ok "thefuck already installed"
fi

# ---------------------------------------------------------------------------
# 7. Clone dotfiles repo
# ---------------------------------------------------------------------------
if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    info "Cloning dotfiles repo..."
    mkdir -p "$(dirname "$DOTFILES_DIR")"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
    info "Dotfiles repo exists, pulling latest..."
    git -C "$DOTFILES_DIR" pull --ff-only || warn "Pull failed (diverged?), continuing with existing state"
fi

# Init core submodules — always runs (idempotent, skips already-init'd)
info "Syncing submodules..."
git -C "$DOTFILES_DIR" submodule update --init .oh-my-zsh .config .tmux/plugins/tpm

# Init nvim and tmux inside .config submodule
if [[ -f "$DOTFILES_DIR/.config/.gitmodules" ]]; then
    git -C "$DOTFILES_DIR/.config" submodule update --init nvim tmux 2>/dev/null || true
fi

ok "Dotfiles repo ready"

# ---------------------------------------------------------------------------
# 8. Powerlevel10k theme
# ---------------------------------------------------------------------------
P10K_DIR="$DOTFILES_DIR/.oh-my-zsh/custom/themes/powerlevel10k"
if [[ ! -d "$P10K_DIR" ]]; then
    info "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    ok "Powerlevel10k installed"
else
    ok "Powerlevel10k already installed"
fi

# ---------------------------------------------------------------------------
# 9. Oh-My-Zsh custom plugins
# ---------------------------------------------------------------------------
ZSH_CUSTOM="$DOTFILES_DIR/.oh-my-zsh/custom"

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
# 10. Back up conflicting dotfiles and stow
# ---------------------------------------------------------------------------
# Top-level files stow will manage
STOW_FILES=(
    .zshrc .zshenv .zprofile .profile .bash_profile
    .p10k.zsh .gitconfig .gitignore_global .gitmodules
    .oh-my-zsh .tmux
)

for f in "${STOW_FILES[@]}"; do
    backup_if_real "$HOME/$f"
done

# .config items managed individually (don't replace the whole .config dir)
mkdir -p "$HOME/.config"
CONFIG_ITEMS=(nvim tmux git)
for item in "${CONFIG_ITEMS[@]}"; do
    backup_if_real "$HOME/.config/$item"
done

if [[ "$BACKUP_NEEDED" == true ]]; then
    ok "Backups saved to $BACKUP_DIR"
fi

# Stow top-level dotfiles (--restow is idempotent — re-links if already stowed)
# Use -d with absolute path to avoid stow bug with absolute symlinks in $HOME
info "Stowing dotfiles..."
stow --restow \
    -d "$(dirname "$DOTFILES_DIR")" \
    -t "$HOME" \
    --ignore='\.config' \
    --ignore='\.local' \
    --ignore='\.git' \
    --ignore='bootstrap\.sh' \
    --ignore='README.*' \
    "$(basename "$DOTFILES_DIR")"

# Symlink .config items individually (ln -sfn is idempotent)
for item in "${CONFIG_ITEMS[@]}"; do
    if [[ -d "$DOTFILES_DIR/.config/$item" ]]; then
        ln -sfn "$DOTFILES_DIR/.config/$item" "$HOME/.config/$item"
        ok "Linked ~/.config/$item"
    fi
done

ok "Dotfiles stowed"

# ---------------------------------------------------------------------------
# 11. Fix hardcoded paths — make dotfiles portable
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

patch_home "$DOTFILES_DIR/.gitconfig"
patch_home "$DOTFILES_DIR/.zshenv"
patch_home "$DOTFILES_DIR/.zprofile"

# ---------------------------------------------------------------------------
# 11b. Taskwarrior 3.x (built from source — apt only ships 2.x)
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
    TW_VERSION=$(curl -fsSL https://api.github.com/repos/GothenburgBitFactory/taskwarrior/releases/latest | jq -r '.tag_name' | sed 's/^v//')
    TW_BUILD_DIR=$(mktemp -d)
    curl -fsSL -o "$TW_BUILD_DIR/task.tar.gz" \
        "https://github.com/GothenburgBitFactory/taskwarrior/releases/download/v${TW_VERSION}/task-${TW_VERSION}.tar.gz"
    tar xzf "$TW_BUILD_DIR/task.tar.gz" -C "$TW_BUILD_DIR"
    cmake -S "$TW_BUILD_DIR/task-${TW_VERSION}" -B "$TW_BUILD_DIR/build" \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local 2>/dev/null
    cmake --build "$TW_BUILD_DIR/build" -j"$(nproc)" 2>/dev/null
    sudo cmake --install "$TW_BUILD_DIR/build" 2>/dev/null
    rm -rf "$TW_BUILD_DIR"
    ok "Taskwarrior ${TW_VERSION} installed"
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
# 12. Install tmux plugins via TPM
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
# 13. Set zsh as default shell
# ---------------------------------------------------------------------------
if [[ "$SHELL" != *"zsh"* ]]; then
    info "Changing default shell to zsh..."
    chsh -s "$(command -v zsh)" || warn "Could not change shell (run: chsh -s $(command -v zsh))"
else
    ok "Default shell is already zsh"
fi

# ---------------------------------------------------------------------------
# 14. Install Nerd Font (for Powerlevel10k icons)
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
# 15. Neovim plugin sync (headless)
# ---------------------------------------------------------------------------
if command -v nvim &>/dev/null; then
    info "Syncing Neovim plugins (lazy.nvim)..."
    nvim --headless "+Lazy! sync" +qa 2>/dev/null && ok "Neovim plugins synced" \
        || warn "Neovim plugin sync failed (open nvim manually to complete setup)"

    info "Updating Mason tool registry..."
    nvim --headless -c "lua require('mason-registry').refresh()" -c "sleep 5" -c "qa" 2>/dev/null \
        && ok "Mason registry updated" \
        || warn "Mason update failed (open nvim manually, tools install on first use)"
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
if [[ "$BACKUP_NEEDED" == true ]]; then
    info "  4. Old dotfiles backed up to: $BACKUP_DIR"
fi
info "  Optional: install Go, Java, SDKMAN as needed"
echo
