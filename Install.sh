#!/bin/bash

set -e

EXECUTE=false

# Check for --execute flag
if [[ "$1" == "--execute" ]]; then
  EXECUTE=true
  echo "🔐 EXECUTION MODE ENABLED — changes will be applied to your system."
else
  echo "🧪 DRY RUN MODE — no changes will be made. Use --execute to apply."
fi

run() {
  if $EXECUTE; then
    echo "▶️ Running: $*"
    eval "$@"
  else
    echo "🧪 Would run: $*"
  fi
}

#==================== Check yay
run "command -v yay"

#==================== Browser Setup
run "pamac build --no-confirm google-chrome"
run "sudo pacman -Rns --noconfirm firefox"
run "rm -rf ~/.mozilla"

#==================== Flatpak Setup
run "sudo pacman -S --noconfirm flatpak"
run "flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"

#==================== Steam
run "flatpak install -y flathub com.valvesoftware.Steam"
run "flatpak override --user --filesystem=/dev/input com.valvesoftware.Steam"
run "flatpak override --user --device=all com.valvesoftware.Steam"

#==================== Heroic Launcher
run "flatpak install -y flathub com.heroicgameslauncher.hgl"

#==================== Focusrite Audio
run "echo 'options snd_usb_audio vid=0x1235 pid=0x8213 device_setup=1' | sudo tee /etc/modprobe.d/snd_usb_audio.conf"
run "yay -S --noconfirm alsa-scarlett-gui"

#==================== Bitwig Studio
run "flatpak install -y flathub com.bitwig.BitwigStudio"

#==================== Discord
run "flatpak install -y flathub com.discordapp.Discord"

#==================== WinBoat Setup
run "yay -S --noconfirm docker docker-compose freerdp qemu-full virt-manager libvirt bridge-utils dnsmasq ebtables iptables-nft dmidecode git"
run "sudo systemctl enable --now docker libvirtd"
run "sudo usermod -aG docker,libvirt \"$(whoami)\""
run "git clone https://github.com/TibixDev/winboat.git \"$HOME/winboat\""
run "cd \"$HOME/winboat\" && docker compose pull"
run "cd \"$HOME/winboat\" && ./scripts/start.sh"

#==================== Yabridge Setup
run "yay -S --noconfirm yabridge wine-staging"
run "yabridgectl sync"
run "yabridgectl add \"$HOME/.wine/drive_c/Program Files/VSTPlugins\""

#==================== Reboot
if $EXECUTE; then
  echo "🔁 Rebooting to apply group changes..."
  reboot
else
  echo "🔁 Would reboot system to apply group changes."
fi
