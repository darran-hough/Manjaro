#==================== Focusrite Audio - https://youtu.be/5zFA5piXf8Q?t=342

#sudo su 
#echo 'options snd_usb_audio vid=0x1235 pid=0x8213 device_setup=1'> /etc/#modprobe.d/snd_usb_audio.conf
#exit

#==================== Focusrite Software
yay -S alsa-scarlett-gui

#==================== Install flatpak and flathub
sudo pacman -S flatpak
sudo systemctl enable --now flatpak-system-helper.service
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub com.obsproject.Studio


#==================== Install flatpak and flathub
#sudo flatpak install ./lightworks-2025.x-AMD64.flatpak
flatpak install flathub com.discordapp.Discord
flatpak install flathub com.valvesoftware.Steam
flatpak install flathub com.brave.Browser
flatpak install flathub com.bitwig.BitwigStudio



sudo pacman -S docker
sudo systemctl enable docker.service
sudo systemctl start docker.service
systemctl status docker
sudo groupadd docker
sudo usermod -aG docker $USER
docker run hello-world
sudo pacman -S docker-compose
sudo systemctl start docker





