#!/bin/bash

set -e

echo "[+] Bootstrapping your setup..."

# Step 0: Download and source custom .bashrc
echo "[+] Downloading your .bashrc..."
curl -fsSL https://raw.githubusercontent.com/indykish/dotfiles/master/.bashrc -o "$HOME/.bashrc"

# Step 1: SSH key setup automation
echo "[+] Setting up SSH configuration..."
# Check if SSH key exists
if [ -f "$HOME/.ssh/id_ed25519" ]; then
    echo "[+] Found SSH key, setting proper permissions..."
    # Set proper permissions for SSH directory and key
    chmod 700 "$HOME/.ssh"
    chmod 600 "$HOME/.ssh/id_ed25519"
    
    # Start SSH agent if not already running
    if [ -z "$SSH_AGENT_PID" ] || ! ps -p $SSH_AGENT_PID > /dev/null; then
        echo "[+] Starting SSH agent..."
        eval $(ssh-agent -s)
    else
        echo "[+] SSH agent already running."
    fi
else
    echo "[!] SSH key not found at $HOME/.ssh/id_ed25519. Exiting."
    exit 1
fi

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
