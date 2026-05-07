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

echo "==> Preserving CachyOS pacman config during Omarchy install"

cp install/post-install/pacman.sh install/post-install/pacman.sh.omarchy-original

cat > install/post-install/pacman.sh <<'PACMAN_POST_EOF'
#!/bin/bash
echo "Preserving CachyOS /etc/pacman.conf and /etc/pacman.d/mirrorlist."
echo "The [omarchy] repo was added manually for CachyOS compatibility."
PACMAN_POST_EOF

chmod +x install/post-install/pacman.sh

echo "==> Patching Omarchy Limine/Snapper script for CachyOS /boot permissions"

cp install/login/limine-snapper.sh install/login/limine-snapper.sh.omarchy-original

sed -i \
  -e 's#\[\[ -f /boot/EFI/arch-limine/limine.conf \]\]#sudo test -f /boot/EFI/arch-limine/limine.conf#g' \
  -e 's#\[\[ -f /boot/EFI/BOOT/limine.conf \]\]#sudo test -f /boot/EFI/BOOT/limine.conf#g' \
  -e 's#\[\[ -f /boot/EFI/limine/limine.conf \]\]#sudo test -f /boot/EFI/limine/limine.conf#g' \
  -e 's#\[\[ -f /boot/limine/limine.conf \]\]#sudo test -f /boot/limine/limine.conf#g' \
  -e 's#\[\[ -f /boot/limine.conf \]\]#sudo test -f /boot/limine.conf#g' \
  -e 's#grep "^\[\[:space:\]\]\*cmdline:" "$limine_config"#sudo grep "^[[:space:]]*cmdline:" "$limine_config"#g' \
  -e 's#\[\[ -f $limine_config \]\]#sudo test -f "$limine_config"#g' \
  -e 's#grep -q "^/+" /boot/limine.conf#sudo grep -q "^/+" /boot/limine.conf#g' \
  -e 's#efibootmgr &>/dev/null#sudo efibootmgr \&>/dev/null#g' \
  -e 's#<(efibootmgr | grep#<(sudo efibootmgr | grep#g' \
  install/login/limine-snapper.sh

chmod +x install/login/limine-snapper.sh

echo
echo "Done!"
echo "To install Omarchy run:"
echo "  tmux new -s omarchy"
echo "  cd ~/.local/share/omarchy"
echo "  bash install.sh"
