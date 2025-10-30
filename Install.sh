#!/bin/bash
set -e

EXECUTE=false

#==================== Check for --execute flag
if [[ "$1" == "--execute" ]]; then
  EXECUTE=true
  echo "🔐 EXECUTION MODE ENABLED — changes will be applied to your system."
else
  echo "🧪 DRY RUN MODE — no changes will be made. Use --execute to apply."
fi

run() {
  local CMD="$*"
  if $EXECUTE; then
    echo "▶️ Running: $CMD"
    if ! eval "$CMD"; then
      echo "❌ Command failed: $CMD"
      echo "⚠️ Skipping failed command."
    fi
  else
    echo "🧪 Would run: $CMD"
  fi
}

check_command() {
  local CMD="$1"
  local PKG="$2"
  if ! command -v "$CMD" &>/dev/null; then
    echo "ℹ️ $CMD not found — installing $PKG..."
    run "sudo pacman -S --needed $PKG --noconfirm"
  else
    echo "✅ $CMD already installed"
  fi
}

#==================== Essential system packages
run "sudo pacman -Syu --noconfirm"
run "sudo pacman -S --needed base-devel git --noconfirm"

#==================== Ensure pamac exists
if ! command -v pamac &>/dev/null; then
  echo "ℹ️ pamac not found — installing pamac-cli..."
  run "sudo pacman -S --needed pamac-cli --noconfirm"
else
  echo "✅ pamac already installed"
fi

#==================== Ensure yay exists
if ! command -v yay &>/dev/null; then
  if [ ! -d "$HOME/yay" ]; then
    run "git clone https://aur.archlinux.org/yay.git \"$HOME/yay\""
  fi
  run "cd \"$HOME/yay\" && makepkg -si --noconfirm"
else
  echo "✅ yay already installed"
fi

#==================== Browser Setup
if ! pacman -Qs google-chrome &>/dev/null; then
  run "pamac build --no-confirm google-chrome"
else
  echo "✅ Google Chrome already installed"
fi

if pacman -Qs firefox &>/dev/null; then
  run "sudo pacman -Rns --noconfirm firefox"
  run "rm -rf ~/.mozilla"
else
  echo "✅ Firefox already removed"
fi

#==================== Flatpak Setup
check_command "flatpak" "flatpak"
if ! flatpak remote-list | grep -q flathub; then
  run "flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
else
  echo "✅ Flathub remote already exists"
fi

#==================== Install Flatpak Apps
FLATPAK_APPS=("com.valvesoftware.Steam" "com.heroicgameslauncher.hgl" "com.bitwig.BitwigStudio" "com.discordapp.Discord")

for APP in "${FLATPAK_APPS[@]}"; do
  if ! flatpak list | grep -q "$APP"; then
    echo "ℹ️ Installing Flatpak app $APP..."
    run "flatpak install -y flathub $APP"
  else
    echo "✅ Flatpak app $APP already installed"
  fi
done

#==================== Apply Flatpak overrides
for APP in "${FLATPAK_APPS[@]}"; do
  echo "ℹ️ Applying Flatpak overrides for $APP..."
  run "flatpak override --user --filesystem=home --filesystem=xdg-data --filesystem=xdg-config --filesystem=xdg-cache --device=all --filesystem=/dev/input $APP"
done

#==================== Focusrite Audio
CONF_FILE="/etc/modprobe.d/snd_usb_audio.conf"
if [ ! -f "$CONF_FILE" ]; then
  run "echo 'options snd_usb_audio vid=0x1235 pid=0x8213 device_setup=1' | sudo tee $CONF_FILE"
else
  echo "✅ Focusrite audio config already exists"
fi
run "yay -S --noconfirm alsa-scarlett-gui"

#==================== WinBoat Setup
run "yay -S --noconfirm docker docker-compose freerdp qemu-full virt-manager libvirt bridge-utils dnsmasq ebtables iptables-nft dmidecode git"
check_command "docker" "docker"
check_command "docker-compose" "docker-compose"
run "sudo systemctl enable --now docker libvirtd"
run "sudo usermod -aG docker,libvirt \"$(whoami)\""

# Refresh group membership for docker/libvirt without logout
if $EXECUTE; then
  echo "ℹ️ Refreshing group membership for docker and libvirt..."
  exec sg docker,newgrp "$0" --execute
fi

if [ ! -d "$HOME/winboat" ]; then
  run "git clone https://github.com/TibixDev/winboat.git \"$HOME/winboat\""
else
  echo "ℹ️ WinBoat folder exists, updating..."
  run "cd \"$HOME/winboat\" && git pull"
fi

run "cd \"$HOME/winboat\" && docker-compose pull"
run "cd \"$HOME/winboat\" && ./scripts/start.sh"

#==================== Yabridge + Wine Dependencies Setup
run "yay -S --noconfirm yabridge wine-staging winetricks"

# Initialize Wine prefix if missing
if [ ! -d "$HOME/.wine" ]; then
  echo "ℹ️ Initializing Wine prefix..."
  run "winecfg -v win64"
fi

# Set environment variables for Yabridge
export WINEPREFIX="$HOME/.wine"
export PATH="$HOME/.wine/drive_c/Program Files/Yabridge/bin:$PATH"

# Install essential Windows libraries via winetricks
echo "ℹ️ Installing essential Windows libraries via winetricks..."
WIN_LIBS=("corefonts" "vcrun2019" "dxvk" "d3dx9" "d3dx11_43" "xact")
for LIB in "${WIN_LIBS[@]}"; do
  run "winetricks -q $LIB"
done

# Ensure VSTPlugins folder exists
VST_DIR="$HOME/.wine/drive_c/Program Files/VSTPlugins"
if [ ! -d "$VST_DIR" ]; then
  echo "ℹ️ Creating VSTPlugins folder at $VST_DIR..."
  run "mkdir -p \"$VST_DIR\""
fi

# Create default VST subfolders
VST_SUBDIRS=("Instruments" "Effects" "Utilities")
for SUB in "${VST_SUBDIRS[@]}"; do
  if [ ! -d "$VST_DIR/$SUB" ]; then
    echo "ℹ️ Creating VST subfolder: $SUB"
    run "mkdir -p \"$VST_DIR/$SUB\""
  fi
done

# Optional free VST downloads
VST_DOWNLOADS=(
  "https://tal-software.com/downloads/tal-noisemaker-3.7.0.zip|Instruments"
  "https://github.com/asb2m10/dexed/releases/download/v0.9.9/Dexed_0.9.9_Win.zip|Instruments"
)

for VST in "${VST_DOWNLOADS[@]}"; do
  URL="${VST%%|*}"
  SUBDIR="${VST##*|}"
  FILE_NAME="${URL##*/}"
  DEST="$VST_DIR/$SUBDIR/$FILE_NAME"

  if [ ! -f "$DEST" ]; then
    echo "ℹ️ Downloading VST: $FILE_NAME to $SUBDIR"
    run "wget -O \"$DEST\" \"$URL\""
    echo "ℹ️ Extracting $FILE_NAME..."
    run "unzip -o \"$DEST\" -d \"$VST_DIR/$SUBDIR\""
  else
    echo "✅ VST $FILE_NAME already exists in $SUBDIR"
  fi
done

# Additional free VST packs
VST_PACKS=(
  "https://labs.spitfireaudio.com/download/LABS_SpliceInstaller.zip|Instruments"
  "https://www.native-instruments.com/fileadmin/ni_media/downloads/MT_Power_Drum_Kit_2.0.zip|Instruments"
  "https://labs.spitfireaudio.com/download/LABS_String_Quartet.zip|Instruments"
)

for PACK in "${VST_PACKS[@]}"; do
  URL="${PACK%%|*}"
  SUBDIR="${PACK##*|}"
  FILE_NAME="${URL##*/}"
  DEST="$VST_DIR/$SUBDIR/$FILE_NAME"

  if [ ! -f "$DEST" ]; then
    echo "ℹ️ Downloading VST pack: $FILE_NAME to $SUBDIR"
    run "wget -O \"$DEST\" \"$URL\""
    echo "ℹ️ Extracting $FILE_NAME..."
    run "unzip -o \"$DEST\" -d \"$VST_DIR/$SUBDIR\""
  else
    echo "✅ VST pack $FILE_NAME already exists in $SUBDIR"
  fi
done

# Sync Yabridge
run "yabridgectl sync"
run "yabridgectl add \"$VST_DIR\""

#==================== Reboot Prompt
if $EXECUTE; then
  read -p "🔁 Installation complete. Do you want to reboot now? (y/N): " REBOOT_CONFIRM
  if [[ "$REBOOT_CONFIRM" =~ ^[Yy]$ ]]; then
    echo "♻️ Rebooting..."
    sudo reboot
  else
    echo "💤 Reboot skipped. Remember to reboot later for group changes to take effect."
  fi
else
  echo "🧪 Dry run complete — would prompt for reboot if executed."
fi
