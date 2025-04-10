#!/bin/bash

set -e

echo "[+] Bootstrapping your setup..."

# Step 0: Download and source custom .bashrc
echo "[+] Downloading your .bashrc..."
curl -fsSL https://raw.githubusercontent.com/indykish/dotfiles/master/.bashrc -o "$HOME/.bashrc"


 Step 1: Install dependencies for mise and ansible
echo "[+] Installing base packages..."
sudo pacman -Sy --noconfirm python-pip base-devel curl


# Step 2: Install mise (if not already installed)
if [ ! -d "$HOME/.local/share/mise" ]; then
  echo "[+] Installing mise..."
  curl https://mise.jdx.dev/install.sh | sh
else
  echo "[✓] mise is already installed"
fi

echo "[+] Sourcing .bashrc..."
source "$HOME/.bashrc"

# Step 3: Install Ansible using mise
echo "[+] Installing Ansible via mise..."
mise install ansible
mise use ansible

# Step 4: Run the Ansible playbook
echo "[+] Running Ansible playbook..."
mise exec ansible -- ansible-playbook playbook.yml

echo "[✓] Done."
