#!/bin/bash
# --------------------------------------------------------------------
# Arch Linux Audio + Gaming Setup Script
# Adapted from Ubuntu 22.04 script by darran-hough
# --------------------------------------------------------------------

set -e

notify () {
  echo "--------------------------------------------------------------------"
  echo "$1"
  echo "--------------------------------------------------------------------"
}

notify "Updating system"
sudo pacman -Syu --noconfirm

# --------------------------------------------------------------------
# Install base packages
# --------------------------------------------------------------------
notify "Installing essential tools"
sudo pacman -S --needed --noconfirm base-devel git curl wget unzip p7zip nano

# --------------------------------------------------------------------
# Install yay (AUR helper) if not already installed
# --------------------------------------------------------------------
if ! command -v yay &>/dev/null; then
  notify "Installing yay (AUR helper)"
  git clone https://aur.archlinux.org/yay.git
  cd yay && makepkg -si --noconfirm
  cd .. && rm -rf yay
fi

# --------------------------------------------------------------------
# Focusrite Scarlett support
# --------------------------------------------------------------------
notify "Setting up Focusrite Scarlett config"
sudo mkdir -p /etc/modprobe.d
echo "options snd_usb_audio vid=0x1235 pid=0x8213 device_setup=1" | sudo tee /etc/modprobe.d/scarlett.conf
# Adjust vid/pid as needed for your model (see geoffreybennett repo)

# alsa-scarlett-gui + firmware
notify "Installing alsa-scarlett-gui"
yay -S --noconfirm alsa-scarlett-gui

# --------------------------------------------------------------------
# Realtime Audio Configuration
# --------------------------------------------------------------------
notify "Configuring realtime audio permissions"

TARGET="/etc/security/limits.conf"
CURRENT_USER="${SUDO_USER:-$USER}"

# Ensure audio and realtime groups exist
for grp in audio realtime; do
  if ! getent group "$grp" > /dev/null; then
    echo "Creating group: $grp"
    sudo groupadd "$grp"
  else
    echo "Group exists: $grp"
  fi
done

# Add user to groups
for grp in audio realtime; do
  if id -nG "$CURRENT_USER" | grep -qw "$grp"; then
    echo "User '$CURRENT_USER' already in group '$grp'"
  else
    echo "Adding user '$CURRENT_USER' to group '$grp'"
    sudo usermod -aG "$grp" "$CURRENT_USER"
  fi
done

# Add realtime limits safely
LIMITS=(
  "@audio - memlock unlimited"
)

if [ -f "$TARGET" ]; then
  for LINE in "${LIMITS[@]}"; do
    if ! grep -qF -- "$LINE" "$TARGET"; then
      echo "Adding line: $LINE"
      echo "$LINE" | sudo tee -a "$TARGET" > /dev/null
    else
      echo "Line already present: $LINE"
    fi
  done
else
  echo "Creating $TARGET and adding realtime limits"
  printf "%s\n" "${LIMITS[@]}" | sudo tee "$TARGET" > /dev/null
fi

# --------------------------------------------------------------------
# Wine (Staging), NVIDIA Utils, Vulkan, and DXVK
# --------------------------------------------------------------------
notify "Installing Wine (Staging), NVIDIA utilities, and Vulkan support"
sudo pacman -S --needed --noconfirm \
  wine-staging wine-mono wine-gecko winetricks cabextract \
  nvidia-utils vulkan-icd-loader vulkan-tools
notify "Downloading and Installing DXVK"
winetricks dxvk

# --------------------------------------------------------------------
# Wine configuration
# --------------------------------------------------------------------
notify "Launching winecfg (please configure your Wine environment)"
winecfg || true

# --------------------------------------------------------------------
# Yabridge
# --------------------------------------------------------------------
notify "Installing Yabridge"
yay -S --noconfirm yabridge yabridgectl

# Create common VST paths
mkdir -p "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST3"

# Add them into yabridge
yabridgectl add "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST3"

# --------------------------------------------------------------------
# Multimedia and productivity tools
# --------------------------------------------------------------------
notify "Installing multimedia tools"
sudo pacman -S --needed --noconfirm vlc gimp piper

# Restricted codecs
sudo pacman -S --needed --noconfirm gst-libav gst-plugins-good gst-plugins-bad gst-plugins-ugly ffmpeg

# --------------------------------------------------------------------
# Flatpak + Flathub Setup
# --------------------------------------------------------------------
notify "Setting up Flatpak and Flathub"
sudo pacman -S --needed --noconfirm flatpak
sudo systemctl enable --now flatpak-system-helper.service
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# --------------------------------------------------------------------
# Web browsers
# --------------------------------------------------------------------
notify "Browser"
yay -S --noconfirm google-chrome

#flatpak install -y flathub com.brave.Browser

# Optional: remove Firefox
sudo pacman -Rns --noconfirm firefox || true

# --------------------------------------------------------------------
# Gaming
# --------------------------------------------------------------------
notify "Installing Steam and Heroic"
sudo pacman -S --needed --noconfirm steam
yay -S --noconfirm heroic-games-launcher-bin

# --------------------------------------------------------------------
# Flatpak Apps
# --------------------------------------------------------------------
notify "Installing Flatpak apps"
flatpak install -y flathub com.discordapp.Discord
flatpak install -y com.rtosta.zapzap

# --------------------------------------------------------------------
# Docker Setup
# --------------------------------------------------------------------
notify "Installing and enabling Docker"
sudo pacman -S --needed --noconfirm docker docker-compose
sudo systemctl enable docker.service
sudo systemctl start docker.service
sudo groupadd docker || true
sudo usermod -aG docker $USER
docker run hello-world || true

# --------------------------------------------------------------------
# Backup
# --------------------------------------------------------------------
notify "Installing backup tool (Deja Dup)"
sudo pacman -S --needed --noconfirm deja-dup

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
