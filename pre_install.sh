#!/usr/bin/env bash
set -e

echo "==> Installing and enabling SSH"
sudo pacman -S --needed openssh
sudo systemctl enable --now sshd

echo "==> Opening SSH port 22/tcp"
if systemctl is-active --quiet firewalld; then
  sudo firewall-cmd --permanent --add-port=22/tcp
  sudo firewall-cmd --reload
elif command -v ufw >/dev/null 2>&1; then
  sudo ufw allow 22/tcp
else
  echo "No active firewalld or ufw found."
fi

echo "==> Adding Omarchy pacman repo"
sudo cp /etc/pacman.conf "/etc/pacman.conf-$(date +%F-%H%M%S)"

if ! grep -q '^\[omarchy\]' /etc/pacman.conf; then
  sudo tee -a /etc/pacman.conf >/dev/null <<'PACMAN_EOF'

[omarchy]
SigLevel = Optional TrustAll
Server = https://pkgs.omarchy.org/stable/$arch
PACMAN_EOF
fi

sudo pacman -Syy

echo "==> Installing tools"
sudo pacman -S --needed git curl base-devel tmux omarchy-keyring

echo "==> Cloning Omarchy"
rm -rf ~/.local/share/omarchy
git clone https://github.com/basecamp/omarchy.git ~/.local/share/omarchy

echo "==> Disabling Omarchy NVIDIA setup"
cd ~/.local/share/omarchy

cp install/config/hardware/nvidia.sh install/config/hardware/nvidia.sh.omarchy-original

cat > install/config/hardware/nvidia.sh <<'NVIDIA_EOF'
#!/bin/bash
echo "Skipping Omarchy NVIDIA setup on CachyOS; CachyOS chwd already installed the NVIDIA driver."
NVIDIA_EOF

chmod +x install/config/hardware/nvidia.sh

echo
echo "Done!"
echo "To install Omarchy run:"
echo "  tmux new -s omarchy"
echo "  cd ~/.local/share/omarchy"
echo "  bash install.sh"
