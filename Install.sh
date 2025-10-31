#!/bin/bash
# --------------------------------------------------------------------
# Arch Linux Audio + Gaming Setup Script (Clean Reinstall Mode)
# Adapted from Ubuntu 22.04 script by darran-hough
# Revised to REINSTALL everything cleanly if it already exists
# --------------------------------------------------------------------

set -e

notify () {
  echo "--------------------------------------------------------------------"
  echo "$1"
  echo "--------------------------------------------------------------------"
}

# --------------------------------------------------------------------
# System Update
# --------------------------------------------------------------------
notify "Updating system"
sudo pacman -Syu --noconfirm

# --------------------------------------------------------------------
# Base Packages
# --------------------------------------------------------------------
notify "Installing essential tools"
sudo pacman -Rns --noconfirm base-devel git curl wget unzip p7zip nano || true
sudo pacman -S --noconfirm base-devel git curl wget unzip p7zip nano

# --------------------------------------------------------------------
# yay (AUR Helper)
# --------------------------------------------------------------------
notify "Installing yay (AUR helper)"
if command -v yay &>/dev/null; then
  echo "Removing old yay..."
  sudo rm -rf "$(which yay)" || true
  sudo rm -rf /usr/bin/yay /opt/yay ~/yay || true
fi
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si --noconfirm
cd .. && rm -rf yay

# --------------------------------------------------------------------
# Focusrite Scarlett Support
# --------------------------------------------------------------------
notify "Setting up Focusrite Scarlett config"
sudo rm -f /etc/modprobe.d/scarlett.conf
sudo mkdir -p /etc/modprobe.d
echo "options snd_usb_audio vid=0x1235 pid=0x8213 device_setup=1" | sudo tee /etc/modprobe.d/scarlett.conf

notify "Installing alsa-scarlett-gui"
yay -Rns --noconfirm alsa-scarlett-gui || true
yay -S --noconfirm alsa-scarlett-gui

# --------------------------------------------------------------------
# Realtime Audio Configuration
# --------------------------------------------------------------------
notify "Configuring realtime audio permissions"

TARGET="/etc/security/limits.conf"
CURRENT_USER="${SUDO_USER:-$USER}"

# Recreate audio and realtime groups
for grp in audio realtime; do
  if getent group "$grp" >/dev/null; then
    echo "Removing existing group $grp..."
    sudo groupdel "$grp" || true
  fi
  sudo groupadd "$grp"
  sudo usermod -aG "$grp" "$CURRENT_USER"
done

# Replace realtime limits
sudo rm -f "$TARGET"
cat <<EOF | sudo tee "$TARGET" >/dev/null
@audio - memlock unlimited
EOF

# --------------------------------------------------------------------
# Wine, NVIDIA, Vulkan, DXVK
# --------------------------------------------------------------------
notify "Reinstalling Wine (Staging), NVIDIA utils, and Vulkan support"
sudo pacman -Rns --noconfirm \
  wine-staging wine-mono wine-gecko winetricks cabextract \
  nvidia-utils vulkan-icd-loader vulkan-tools || true

sudo pacman -S --noconfirm \
  wine-staging wine-mono wine-gecko winetricks cabextract \
  nvidia-utils vulkan-icd-loader vulkan-tools

notify "Reinstalling DXVK"
rm -rf ~/.local/share/wineprefixes/default/dxvk* ~/.cache/winetricks/dxvk* || true
winetricks -q dxvk

# --------------------------------------------------------------------
# Wine configuration
# --------------------------------------------------------------------
notify "Launching winecfg (please configure your Wine environment)"
winecfg || true

# --------------------------------------------------------------------
# Yabridge
# --------------------------------------------------------------------
notify "Reinstalling Yabridge"
yay -Rns --noconfirm yabridge yabridgectl || true
yay -S --noconfirm yabridge yabridgectl

# Reset Yabridge configuration
yabridgectl clear || true

# Recreate common VST paths
VST_PATHS=(
  "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
  "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
  "$HOME/.wine/drive_c/Program Files/Common Files/VST3"
)
for path in "${VST_PATHS[@]}"; do
  rm -rf "$path"
  mkdir -p "$path"
  yabridgectl add "$path"
done

# --------------------------------------------------------------------
# Multimedia Tools
# --------------------------------------------------------------------
notify "Reinstalling multimedia tools"
sudo pacman -Rns --noconfirm vlc gimp piper gst-libav gst-plugins-good gst-plugins-bad gst-plugins-ugly ffmpeg || true
sudo pacman -S --noconfirm vlc gimp piper gst-libav gst-plugins-good gst-plugins-bad gst-plugins-ugly ffmpeg

# --------------------------------------------------------------------
# Flatpak + Flathub
# --------------------------------------------------------------------
notify "Reinstalling Flatpak and Flathub"
sudo pacman -Rns --noconfirm flatpak || true
sudo pacman -S --noconfirm flatpak
sudo systemctl enable --now flatpak-system-helper.service
flatpak remote-delete flathub || true
flatpak remote-add flathub https://flathub.org/repo/flathub.flatpakrepo

# --------------------------------------------------------------------
# Browser
# --------------------------------------------------------------------
notify "Reinstalling Google Chrome"
yay -Rns --noconfirm google-chrome || true
yay -S --noconfirm google-chrome

# Remove Firefox if present
sudo pacman -Rns --noconfirm firefox || true

# --------------------------------------------------------------------
# Gaming
# --------------------------------------------------------------------
notify "Reinstalling Steam and Heroic"
sudo pacman -Rns --noconfirm steam || true
yay -Rns --noconfirm heroic-games-launcher-bin || true
sudo pacman -S --noconfirm steam
yay -S --noconfirm heroic-games-launcher-bin

# --------------------------------------------------------------------
# Flatpak Apps
# --------------------------------------------------------------------
notify "Reinstalling Flatpak apps"
flatpak uninstall -y com.discordapp.Discord com.rtosta.zapzap || true
flatpak install -y flathub com.discordapp.Discord
flatpak install -y flathub com.rtosta.zapzap

# --------------------------------------------------------------------
# Docker Setup
# --------------------------------------------------------------------
notify "Reinstalling Docker"
sudo systemctl stop docker.service || true
sudo pacman -Rns --noconfirm docker docker-compose || true
sudo pacman -S --noconfirm docker docker-compose
sudo systemctl enable --now docker.service
sudo groupdel docker || true
sudo groupadd docker
sudo usermod -aG docker "$USER"
docker run hello-world || true

# --------------------------------------------------------------------
# Backup
# --------------------------------------------------------------------
notify "Reinstalling Deja Dup"
sudo pacman -Rns --noconfirm deja-dup || true
sudo pacman -S --noconfirm deja-dup

# --------------------------------------------------------------------
# Cleanup
# --------------------------------------------------------------------
notify "Cleaning up"
ORPHANS=$(pacman -Qtdq || true)
if [ -n "$ORPHANS" ]; then
  sudo pacman -Rns --noconfirm $ORPHANS
fi
sudo pacman -Scc --noconfirm

notify "Setup complete! Please reboot to apply all changes."
read -p "Press Enter to reboot or Ctrl+C to cancel..."
reboot
