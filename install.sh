#!/bin/bash
# Install Token Tally on Omarchy / Arch Linux.
#   curl -fsSL https://raw.githubusercontent.com/FabianJ-L/tokentally/master/install.sh | bash
set -euo pipefail

REPO="https://github.com/FabianJ-L/tokentally"

if ! command -v pacman >/dev/null 2>&1; then
  echo "Token Tally installs with pacman (Omarchy / Arch Linux). Build it by hand on other systems: $REPO#build" >&2
  exit 1
fi
if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user, not root. It asks for sudo when it needs it." >&2
  exit 1
fi

echo "Installing build tools and Qt 6..."
sudo pacman -S --needed --noconfirm base-devel git qt6-base qt6-declarative qt6-wayland

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Downloading Token Tally..."
git clone --depth 1 "$REPO" "$WORK/tokentally"

echo "Building and installing..."
cd "$WORK/tokentally/pkgbuild"
makepkg -fsi --noconfirm

echo
echo "Done. Open Token Tally from the app launcher (Super + Space), or run: tokentally"
