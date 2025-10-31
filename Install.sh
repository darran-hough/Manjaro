#!/bin/bash
# --------------------------------------------------------------------
# Arch Linux Audio + Gaming Setup Script
# Adapted from Ubuntu 22.04 script by darran-hough
# Revised to skip existing installs/configs
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
else
  echo "yay already installed — skipping"
fi

# --------------------------------------------------------------------
# Focusrite Scarlett support
# --------------------------------------------------------------------
notify "Setting up Focusrite Scarlett config"
SCARLETT_CONF="/etc/modprobe.d/scarlett.conf"
if [ ! -f "$SCARLETT_CONF" ]; then
  echo "options snd_usb_audio vid=0x1235 pid=0x8213 device_setup=1" | sudo tee "$SCARLETT_CONF"
else
  echo "Scarlett config already exists — skipping"
fi

# alsa-scarlett-gui + firmware
notify "Installing alsa-scarlett-gui"
if ! yay -Q alsa-scarlett-gui &>/dev/null; then
  yay -S --noconfirm alsa-scarlett-gui
else
  echo "alsa-scarlett-gui already installed — skipping"
fi

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
if ! winetricks list-installed | grep -q dxvk; then
  winetricks dxvk
else
  echo "DXVK already installed — skipping"
fi

# --------------------------------------------------------------------
# Wine configuration
# --------------------------------------------------------------------
notify "Launching winecfg (please configure your Wine environment)"
winecfg || true

# --------------------------------------------------------------------
# Yabridge
# --------------------------------------------------------------------
notify "Installing Yabridge"
if ! yay -Q yabridge &>/dev/null; then
  yay -S --noconfirm yabridge yabridgectl
else
  echo "Yabridge already installed — skipping"
fi

# Create common VST paths
VST_PATHS=(
  "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
  "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
  "$HOME/.wine/drive_c/Program Files/Common Files/VST3"
)
for path in "${VST_PATHS[@]}"; do
  mkdir -p "$path"
  yabridgectl add "$path" || true
done

# --------------------------------------------------------------------
# Multimedia and productivity tools
# --------------------------------------------------------------------
notify "Installing multimedia tools"
sudo pacman -S --needed --noconfirm vlc gimp piper gst-libav gst-plugins-good gst-plugins-bad gst-plugins-ugly ffmpeg

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
notify "Installing Google Chrome"
if ! yay -Q google-chrome &>/dev/null; then
  yay -S --noconfirm google-chrome
else
  echo "Google Chrome already installed — skipping"
fi

# Optional: remove Firefox
sudo pacman -Rns --noconfirm firefox || true

# --------------------------------------------------------------------
# Gaming
# --------------------------------------------------------------------
notify "Installing Steam and Heroic"
sudo pacman -S --needed --noconfirm steam
if ! yay -Q heroic-games-launcher-bin &>/dev/null; then
  yay -S --noconfirm heroic-games-launcher-bin
else
  echo "Heroic Games Launcher already installed — skipping"
fi

# --------------------------------------------------------------------
# Flatpak Apps
# --------------------------------------------------------------------
notify "Installing Flatpak apps"
flatpak install -y flathub com.discordapp.Discord || echo "Discord already installed"
flatpak install -y flathub com.rtosta.zapzap || echo "Zapzap already installed"

# --------------------------------------------------------------------
# Docker Setup
# --------------------------------------------------------------------
notify "Installing and enabling Docker"
sudo pacman -S --needed --noconfirm docker docker-compose
sudo systemctl enable --now docker.service
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker "$USER"
docker run hello-world || true

# --------------------------------------------------------------------
# Backup
# --------------------------------------------------------------------
notify "Installing backup tool (Deja Dup)"
sudo pacman -S --needed --noconfirm deja-dup

# --------------------------------------------------------------------
# GNOME Dock Favorites
# --------------------------------------------------------------------
notify "Pinning installed apps to the GNOME Dock"

FAVORITES=(
  "google-chrome.desktop"
  "org.gnome.Nautilus.desktop"
  "org.gnome.Terminal.desktop"
  "vlc.desktop"
  "gimp.desktop"
  "com.discordapp.Discord.desktop"
  "steam.desktop"
  "heroic-games-launcher-bin.desktop"
  "deja-dup.desktop"
)

# Retrieve current favorites
CURRENT_FAVORITES=$(gsettings get org.gnome.shell favorite-apps)

# Append any missing apps
for app in "${FAVORITES[@]}"; do
  if [[ "$CURRENT_FAVORITES" != *"$app"* ]]; then
    CURRENT_FAVORITES=$(echo "$CURRENT_FAVORITES" | sed "s/]$/, '$app']/")
  fi
done

# Apply updated favorites list
gsettings set org.gnome.shell favorite-apps "$CURRENT_FAVORITES"

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
