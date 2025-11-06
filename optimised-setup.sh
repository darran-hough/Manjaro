#!/usr/bin/env bash
# --------------------------------------------------------------------
# Arch Linux / Manjaro Audio + Gaming Setup Script
# Adapted from Ubuntu 22.04 script by darran-hough
# Optimized and idempotent version (2025)
# --------------------------------------------------------------------
sudo pacman -Syu
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
# Realtime Audio Configuration (PipeWire optimized)
# --------------------------------------------------------------------
notify "Configuring realtime audio permissions (PipeWire compatible)"

# Ensure audio + realtime groups exist
for grp in audio realtime; do
  getent group "$grp" >/dev/null || sudo groupadd "$grp"
  if ! id -nG "${SUDO_USER:-$USER}" | grep -qw "$grp"; then
    sudo usermod -aG "$grp" "${SUDO_USER:-$USER}"
  fi
done

# Ensure PAM is installed (some lightweight Manjaro editions omit it)
if ! pacman -Qi pambase &>/dev/null; then
  notify "Installing PAM base package (pambase)"
  sudo pacman -S --needed --noconfirm pambase
fi

# PAM limits configuration
LIMITS_DIR="/etc/security/limits.d"
LIMITS_FILE="$LIMITS_DIR/99-audio.conf"

# Create directory if missing
if [[ ! -d "$LIMITS_DIR" ]]; then
  sudo mkdir -p "$LIMITS_DIR"
  sudo chmod 755 "$LIMITS_DIR"
  echo "Created missing directory: $LIMITS_DIR"
fi

# Create or verify the realtime limits file
if [[ ! -f $LIMITS_FILE ]]; then
  sudo tee "$LIMITS_FILE" >/dev/null <<'EOF'
@audio   -   rtprio     95
@audio   -   nice      -19
@audio   -   memlock    unlimited
EOF
  echo "Created $LIMITS_FILE"
else
  echo "$LIMITS_FILE already exists — skipping"
fi

# Ensure PAM limits module is loaded
for pam_file in /etc/pam.d/common-session /etc/pam.d/common-session-noninteractive; do
  if [[ -f "$pam_file" ]] && ! grep -q pam_limits.so "$pam_file"; then
    echo "session required pam_limits.so" | sudo tee -a "$pam_file" >/dev/null
    echo "Added pam_limits.so to $pam_file"
  fi
done

# Systemd limits for PipeWire & WirePlumber
SYSTEMD_DIR="/etc/systemd/system.conf.d"
USERD_DIR="/etc/systemd/user.conf.d"
sudo mkdir -p "$SYSTEMD_DIR" "$USERD_DIR"

sudo tee "$SYSTEMD_DIR/95-audio.conf" >/dev/null <<'EOF'
[Manager]
DefaultLimitRTPRIO=95
DefaultLimitMEMLOCK=infinity
DefaultLimitNICE=-19
EOF

sudo tee "$USERD_DIR/95-audio.conf" >/dev/null <<'EOF'
[Manager]
DefaultLimitRTPRIO=95
DefaultLimitMEMLOCK=infinity
DefaultLimitNICE=-19
EOF

# Reload systemd to apply new limits
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
systemctl --user daemon-reexec || true
systemctl --user daemon-reload || true

# Enable and verify PipeWire + WirePlumber
notify "Enabling PipeWire and WirePlumber user services"
for svc in pipewire.service pipewire-pulse.service wireplumber.service; do
  systemctl --user enable --now "$svc" || true
done

sleep 2
notify "Verifying PipeWire and WirePlumber status"
systemctl --user --no-pager --full status pipewire.service pipewire-pulse.service wireplumber.service | grep -E "Loaded|Active" || true

echo -e "\n\033[1;32mPipeWire realtime configuration complete.\033[0m"
echo "You may need to log out and back in (or reboot) for group membership changes to take effect."

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
sudo systemctl enable --now flatpak-system-helper.service || true
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
notify "Installing Steam, Heroic, and ProtonUp-Qt"
pkg_install pacman steam
pkg_install yay heroic-games-launcher-bin protonup-qt

# Auto-install Proton-GE using ProtonUp CLI
notify "Installing latest Proton-GE versions via ProtonUp-Qt CLI"
if command -v protonup-qt &>/dev/null; then
  protonup-qt --install --latest --for steam || true
  protonup-qt --install --latest --for heroic || true
else
  echo "ProtonUp-Qt CLI not found — skipping Proton-GE install."
fi

echo "✅ Proton-GE installed for Steam and Heroic (via ProtonUp-Qt CLI)."

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
  protonup-qt.desktop
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
