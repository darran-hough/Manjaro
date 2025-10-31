#!/usr/bin/env bash
# --------------------------------------------------------------------
# Arch Linux Audio + Gaming Setup Script
# Adapted from Ubuntu 22.04 script by darran-hough
# Optimized and idempotent version (2025)
# --------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# --------------------------------------------------------------------
# Functions
# --------------------------------------------------------------------
notify() {
  echo -e "\n\033[1;36m==> $1\033[0m\n"
}

pkg_install() {
  local manager="$1"; shift
  local pkgs=("$@")
  case "$manager" in
    pacman)
      sudo pacman -S --needed --noconfirm "${pkgs[@]}"
      ;;
    yay)
      yay -S --needed --noconfirm "${pkgs[@]}"
      ;;
  esac
}

already_installed() {
  local pkg="$1"
  pacman -Q "$pkg" &>/dev/null || yay -Q "$pkg" &>/dev/null
}

# --------------------------------------------------------------------
# Update system
# --------------------------------------------------------------------
notify "Updating system"
sudo pacman -Syu --noconfirm

# --------------------------------------------------------------------
# Essentials
# --------------------------------------------------------------------
notify "Installing essential tools"
pkg_install pacman base-devel git curl wget unzip p7zip nano

# --------------------------------------------------------------------
# Yay setup
# --------------------------------------------------------------------
if ! command -v yay &>/dev/null; then
  notify "Installing yay (AUR helper)"
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  pushd /tmp/yay >/dev/null
  makepkg -si --noconfirm
  popd >/dev/null
  rm -rf /tmp/yay
else
  echo "yay already installed — skipping"
fi

# --------------------------------------------------------------------
# Focusrite Scarlett support
# --------------------------------------------------------------------
notify "Setting up Focusrite Scarlett config"
SCARLETT_CONF="/etc/modprobe.d/scarlett.conf"
if [[ ! -f $SCARLETT_CONF ]]; then
  echo "options snd_usb_audio vid=0x1235 pid=0x8213 device_setup=1" | sudo tee "$SCARLETT_CONF"
else
  echo "Scarlett config already exists — skipping"
fi

pkg_install yay alsa-scarlett-gui

# --------------------------------------------------------------------
# Realtime Audio Configuration
# --------------------------------------------------------------------
notify "Configuring realtime audio permissions"

for grp in audio realtime; do
  getent group "$grp" >/dev/null || sudo groupadd "$grp"
  if ! id -nG "${SUDO_USER:-$USER}" | grep -qw "$grp"; then
    sudo usermod -aG "$grp" "${SUDO_USER:-$USER}"
  fi
done

LIMITS_FILE="/etc/security/limits.conf"
LIMIT_LINE="@audio - memlock unlimited"
grep -qxF "$LIMIT_LINE" "$LIMITS_FILE" 2>/dev/null || echo "$LIMIT_LINE" | sudo tee -a "$LIMITS_FILE" >/dev/null

# --------------------------------------------------------------------
# Wine + DXVK + NVIDIA + Vulkan
# --------------------------------------------------------------------
notify "Installing Wine (Staging), NVIDIA utilities, and Vulkan support"
pkg_install pacman \
  wine-staging wine-mono wine-gecko winetricks cabextract \
  nvidia-utils vulkan-icd-loader vulkan-tools

notify "Installing DXVK"
winetricks list-installed 2>/dev/null | grep -q dxvk || winetricks -q dxvk

# --------------------------------------------------------------------
# Wine configuration
# --------------------------------------------------------------------
notify "Launching winecfg (configure your Wine environment)"
winecfg || true

# --------------------------------------------------------------------
# Yabridge
# --------------------------------------------------------------------
notify "Installing Yabridge"
pkg_install yay yabridge yabridgectl

VST_PATHS=(
  "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
  "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
  "$HOME/.wine/drive_c/Program Files/Common Files/VST3"
)
for path in "${VST_PATHS[@]}"; do
  mkdir -p "$path"
  yabridgectl add "$path" 2>/dev/null || true
done

# --------------------------------------------------------------------
# Multimedia + Productivity
# --------------------------------------------------------------------
notify "Installing multimedia tools"
pkg_install pacman vlc gimp piper gst-libav gst-plugins-{good,bad,ugly} ffmpeg

# --------------------------------------------------------------------
# Flatpak + Flathub
# --------------------------------------------------------------------
notify "Setting up Flatpak and Flathub"
pkg_install pacman flatpak
sudo systemctl enable --now flatpak-system-helper.service
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# --------------------------------------------------------------------
# Web Browsers
# --------------------------------------------------------------------
notify "Installing Google Chrome"
pkg_install yay google-chrome
sudo pacman -Rns --noconfirm firefox || true

# --------------------------------------------------------------------
# Gaming
# --------------------------------------------------------------------
notify "Installing Steam and Heroic Games Launcher"
pkg_install pacman steam
pkg_install yay heroic-games-launcher-bin

# --------------------------------------------------------------------
# Flatpak Apps
# --------------------------------------------------------------------
notify "Installing Flatpak apps"
flatpak install -y flathub com.discordapp.Discord com.rtosta.zapzap || true

# --------------------------------------------------------------------
# Bitwig Studio
# --------------------------------------------------------------------
notify "Installing Bitwig Studio"
pkg_install yay bitwig-studio

# --------------------------------------------------------------------
# Docker Setup
# --------------------------------------------------------------------
notify "Installing and enabling Docker"
pkg_install pacman docker docker-compose
sudo systemctl enable --now docker.service
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker "$USER"
docker run hello-world || true

# --------------------------------------------------------------------
# Backup Tool
# --------------------------------------------------------------------
notify "Installing backup tool (Deja Dup)"
pkg_install pacman deja-dup

# --------------------------------------------------------------------
# GNOME Dock Favorites
# --------------------------------------------------------------------
notify "Updating GNOME Dock favorites"

FAVORITES=(
  google-chrome.desktop
  org.gnome.Terminal.desktop
  com.discordapp.Discord.desktop
  steam.desktop
  heroic.desktop
  org.freedesktop.Piper.desktop
  com.bitwig.BitwigStudio.desktop
  com.rtosta.zapzap.desktop
)

CURRENT=$(gsettings get org.gnome.shell favorite-apps)
for app in "${FAVORITES[@]}"; do
  [[ "$CURRENT" == *"$app"* ]] || CURRENT=$(echo "$CURRENT" | sed "s/]$/, '$app']/")
done
gsettings set org.gnome.shell favorite-apps "$CURRENT"

# --------------------------------------------------------------------
# Cleanup
# --------------------------------------------------------------------
notify "Cleaning up"
ORPHANS=$(pacman -Qtdq || true)
[[ -n "$ORPHANS" ]] && sudo pacman -Rns --noconfirm $ORPHANS
sudo pacman -Scc --noconfirm

# --------------------------------------------------------------------
# Done
# --------------------------------------------------------------------
notify "✅ Setup complete! A reboot is recommended to apply all changes."

read -rp "Would you like to reboot now? [y/N]: " REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  echo "Rebooting..."
  reboot
else
  echo "Reboot skipped. Please reboot manually later to finalize setup."
fi
