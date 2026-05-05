#!/usr/bin/env bash
set -euo pipefail

NVIM_VERSION="v0.12.2"
NVIM_DIR="$HOME/.local/nvim-linux-x86_64"
NVIM_BIN="$HOME/.local/bin/nvim"
CONFIG_DIR="$HOME/.config/nvim"
REPO_URL="https://github.com/cameronrothenburg/nvim.git"

echo "=== Neovim Setup ==="

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" ]]; then
    echo "Error: Only x86_64 is supported by this script (detected: $ARCH)"
    exit 1
fi

# Install dependencies via apt
echo "[1/4] Installing dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq build-essential ripgrep fd-find nodejs npm python3-pip python3-venv git curl unzip

# Download and install Neovim
echo "[2/4] Installing Neovim $NVIM_VERSION..."
mkdir -p "$HOME/.local/bin"
TARBALL="/tmp/nvim-linux-x86_64.tar.gz"
curl -fsSL "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" -o "$TARBALL"
rm -rf "$NVIM_DIR"
tar -C "$HOME/.local" -xzf "$TARBALL"
ln -sf "$NVIM_DIR/bin/nvim" "$NVIM_BIN"
rm "$TARBALL"

# Ensure ~/.local/bin is on PATH
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    SHELL_RC="$HOME/.bashrc"
    [[ -n "${ZSH_VERSION:-}" ]] && SHELL_RC="$HOME/.zshrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    export PATH="$HOME/.local/bin:$PATH"
    echo "  Added ~/.local/bin to PATH in $(basename "$SHELL_RC")"
fi

# Clone config
echo "[3/4] Installing nvim config..."
if [[ -d "$CONFIG_DIR" ]]; then
    echo "  Backing up existing config to ${CONFIG_DIR}.bak"
    rm -rf "${CONFIG_DIR}.bak"
    mv "$CONFIG_DIR" "${CONFIG_DIR}.bak"
fi
git clone "$REPO_URL" "$CONFIG_DIR"

# Verify
echo "[4/4] Verifying..."
"$NVIM_BIN" --version | head -1

echo ""
echo "Done! Run 'nvim' to finish plugin installation."
echo "If nvim is not found, restart your shell or run: export PATH=\"\$HOME/.local/bin:\$PATH\""
