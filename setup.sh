#!/usr/bin/env bash
# Ubuntu/Debian install or update. Never resets or deletes an existing config.
set -euo pipefail
NVIM_VERSION="v0.12.6"
REPO_URL="https://github.com/cameronrothenburg/nvim.git"
CONFIG_DIR="${NVIM_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/nvim}"
BIN_DIR="$HOME/.local/bin"
die() { printf '%s\n' "$*" >&2; exit 1; }
case "$(uname -m)" in
  x86_64) NVIM_ARCH=x86_64; NODE_ARCH=x64 ;;
  aarch64|arm64) NVIM_ARCH=arm64; NODE_ARCH=arm64 ;;
  *) die "Unsupported architecture: $(uname -m)" ;;
esac
[[ "$(uname -s)" == Linux ]] || die "Use setup.ps1 on Windows. This script targets Ubuntu/Debian."
command -v apt-get >/dev/null || die "This installer requires Ubuntu/Debian (apt-get)."
SUDO=()
if [[ "$EUID" -ne 0 ]]; then SUDO=(sudo); fi
"${SUDO[@]}" apt-get update
"${SUDO[@]}" apt-get install -y git curl ca-certificates tar xz-utils unzip build-essential ripgrep fd-find

# Refuse to overwrite unrelated checkouts or local work.
if [[ -e "$CONFIG_DIR" ]]; then
  [[ -d "$CONFIG_DIR/.git" ]] || die "Config exists at $CONFIG_DIR. Move it aside first; nothing was overwritten."
  origin=$(git -C "$CONFIG_DIR" remote get-url origin)
  case "$origin" in
    https://github.com/cameronrothenburg/nvim|https://github.com/cameronrothenburg/nvim.git|git@github.com:cameronrothenburg/nvim.git) ;;
    *) die "Existing config belongs to a different repository: $origin" ;;
  esac
  [[ -z "$(git -C "$CONFIG_DIR" status --porcelain)" ]] || die "Config has local changes. Commit or stash them before updating."
  [[ "$(git -C "$CONFIG_DIR" branch --show-current)" == master ]] || die "Switch the config to master before updating."
  git -C "$CONFIG_DIR" pull --ff-only origin master
else
  mkdir -p "$(dirname "$CONFIG_DIR")"
  git clone --branch master "$REPO_URL" "$CONFIG_DIR"
fi

mkdir -p "$BIN_DIR"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
archive="nvim-linux-${NVIM_ARCH}"
install_dir="$HOME/.local/lib/nvim-${NVIM_VERSION}-${NVIM_ARCH}"
if [[ ! -x "$install_dir/bin/nvim" ]]; then
  curl -fL --retry 3 "https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/$archive.tar.gz" -o "$stage/nvim.tar.gz"
  tar -xzf "$stage/nvim.tar.gz" -C "$stage"
  mkdir -p "$(dirname "$install_dir")"
  [[ ! -e "$install_dir" ]] || die "Incomplete installation at $install_dir; move it aside and retry."
  mv "$stage/$archive" "$install_dir"
fi
ln -sfn "$install_dir/bin/nvim" "$BIN_DIR/nvim"
export PATH="$BIN_DIR:$PATH"

# Ubuntu's stock Node may be too old. Use an official Node 24 LTS binary, locally.
node_major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)
if (( node_major < 22 )); then
  curl -fL --retry 3 https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt -o "$stage/SHASUMS256.txt"
  node_archive=$(awk -v suffix="-linux-${NODE_ARCH}.tar.xz" 'index($2,suffix) && substr($2,length($2)-length(suffix)+1)==suffix {print $2}' "$stage/SHASUMS256.txt")
  [[ "$node_archive" =~ ^node-v24\.[0-9]+\.[0-9]+-linux-${NODE_ARCH}\.tar\.xz$ ]] || die "Cannot resolve a Node 24 release."
  curl -fL --retry 3 "https://nodejs.org/dist/latest-v24.x/$node_archive" -o "$stage/$node_archive"
  (cd "$stage"; awk -v name="$node_archive" '$2==name' SHASUMS256.txt | sha256sum -c -)
  tar -xJf "$stage/$node_archive" -C "$stage"
  node_dir="$HOME/.local/lib/${node_archive%.tar.xz}"
  mkdir -p "$(dirname "$node_dir")"
  if [[ ! -d "$node_dir" ]]; then mv "$stage/${node_archive%.tar.xz}" "$node_dir"; fi
  for binary in node npm npx; do ln -sfn "$node_dir/bin/$binary" "$BIN_DIR/$binary"; done
fi
if ! command -v fd >/dev/null; then ln -sfn "$(command -v fdfind)" "$BIN_DIR/fd"; fi
path_line='export PATH="$HOME/.local/bin:$PATH"'
for shell_rc in "$HOME/.profile" "$HOME/.bashrc"; do
  touch "$shell_rc"
  grep -Fxq "$path_line" "$shell_rc" || printf '\n%s\n' "$path_line" >> "$shell_rc"
done
if [[ "${SHELL:-}" == */zsh ]]; then
  touch "$HOME/.zshrc"
  grep -Fxq "$path_line" "$HOME/.zshrc" || printf '\n%s\n' "$path_line" >> "$HOME/.zshrc"
fi
npm ci --prefix "$CONFIG_DIR/tools" --no-fund --no-audit
if [[ "${NVIM_SKIP_SYNC:-0}" != 1 ]]; then
  XDG_CONFIG_HOME="$(dirname "$CONFIG_DIR")" NVIM_APPNAME="$(basename "$CONFIG_DIR")" \
    "$BIN_DIR/nvim" --headless '+Lazy! restore' +qa
fi
"$BIN_DIR/nvim" --version | sed -n '1p'
printf '\nReady. Restart your shell, then run: nvim\n'
printf 'Sign in once: node "%s/tools/node_modules/@agentclientprotocol/codex-acp/dist/index.js" login\n' "$CONFIG_DIR"
printf 'Space aa: discuss. Select code, Space ae: edit. README.md has the workflow.\n'
