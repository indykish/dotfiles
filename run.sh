#!/bin/bash

set -e

echo "[+] Bootstrapping your setup..."

# Step 1: Download and source custom .bashrc
echo "[+] Downloading your .bashrc..."
curl -fsSL https://raw.githubusercontent.com/indykish/dotfiles/master/.bashrc -o "$HOME/.bashrc"


# Step 2: Install dependencies for mise and ansible
echo "[+] Installing base packages..."
packages=(git curl python-pip python-pipx firefox noto-fonts noto-fonts-extra ansible)

for pkg in "${packages[@]}"; do
  if ! pacman -Q $pkg &>/dev/null; then
    echo "[+] Installing $pkg..."
    sudo pacman -S --noconfirm $pkg
  else
    echo "[✓] $pkg already installed"
  fi
done


# Step 3: Install mise (if not already installed)
if ! command -v mise &> /dev/null; then
  echo "[+] Installing mise..."
  curl https://mise.jdx.dev/install.sh | sh
else
  echo "[✓] mise is already installed"
fi

# Step 4: Run it *only for this session* (won’t hang the script)
echo "[+] Activating mise for this session"
eval "$(mise activate bash)"


# Step 5: Run the Ansible playbook
echo "[+] Running Ansible playbook..."
ansible-playbook --verbose playbook.yml

echo "[✓] Done."
