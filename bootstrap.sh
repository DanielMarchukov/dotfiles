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
    fzf fd-find bat ripgrep zoxide \
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
# 2. GitHub CLI
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
# 4. Rust (via rustup)
# ---------------------------------------------------------------------------
if ! command -v rustup &>/dev/null; then
    info "Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --quiet
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"
    ok "Rust installed: $(rustc --version)"
else
    ok "Rust: $(rustc --version)"
fi

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
pipx ensurepath 2>/dev/null || true
export PATH="$HOME/.local/bin:$PATH"

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
info "Stowing dotfiles..."
cd "$DOTFILES_DIR"
stow --restow \
    --ignore='\.config' \
    --ignore='\.local' \
    --ignore='\.git' \
    --ignore='bootstrap\.sh' \
    --ignore='README.*' \
    -t "$HOME" .

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
info "  Optional: install vcpkg, Go, Java, SDKMAN as needed"
echo
