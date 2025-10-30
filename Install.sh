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
# Wine (staging) and dependencies
# --------------------------------------------------------------------
notify "Installing Wine and Winetricks"
sudo pacman -S --needed --noconfirm wine-staging wine-mono wine-gecko winetricks cabextract

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
# Gaming
# --------------------------------------------------------------------
notify "Installing Steam and Heroic"
sudo pacman -S --needed --noconfirm steam
yay -S --noconfirm heroic-games-launcher-bin

# --------------------------------------------------------------------
# Communication tools
# --------------------------------------------------------------------
notify "Installing Discord and WhatsApp"
sudo pacman -S --needed --noconfirm discord
yay -S --noconfirm whatsie-bin

# --------------------------------------------------------------------
# Web browsers
# --------------------------------------------------------------------
notify "Installing Chrome"
yay -S --noconfirm google-chrome

# Optional: remove Firefox
sudo pacman -Rns --noconfirm firefox || true

# --------------------------------------------------------------------
# Flatpak + Flathub Setup
# --------------------------------------------------------------------
notify "Setting up Flatpak and Flathub"
sudo pacman -S --needed --noconfirm flatpak
sudo systemctl enable --now flatpak-system-helper.service
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# --------------------------------------------------------------------
# Flatpak Apps
# --------------------------------------------------------------------
notify "Installing Flatpak apps"
flatpak install -y flathub com.obsproject.Studio
flatpak install -y flathub com.discordapp.Discord
flatpak install -y flathub com.valvesoftware.Steam
flatpak install -y flathub com.brave.Browser
flatpak install -y flathub com.bitwig.BitwigStudio

# Uncomment the line below to install Lightworks manually from a local file:
# sudo flatpak install ./lightworks-2025.x-AMD64.flatpak

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
sudo pacman -Rns $(pacman -Qtdq) --noconfirm || true
sudo pacman -Scc --noconfirm

notify "Setup complete! Please reboot to apply all changes."
read -p "Press Enter to reboot or Ctrl+C to cancel..."
reboot
