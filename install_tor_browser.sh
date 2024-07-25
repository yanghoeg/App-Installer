#!/data/data/com.termux/files/usr/bin/bash
varname=$(basename $PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu/home/*)

cd

# Installation steps for Tor Browser
proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0 sudo -S apt install firefox-esr -y
proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0 curl -sLO https://sourceforge.net/projects/tor-browser-ports/files/13.0.9/tor-browser-linux-arm64-13.0.9_ALL.tar.xz/download
proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0 mv download tor.tar.xz
proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0 tar -xvf tor.tar.xz
proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0 rm tor.tar.xz

# Create the desktop entry
echo "[Desktop Entry]
Type=Application
Name=Tor Browser
GenericName=Web Browser
Comment=Tor Browser is +1 for privacy and −1 for mass surveillance
Categories=Network;WebBrowser;Security;
Exec=proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0  tor-browser/Browser/start-tor-browser --no-sandbox
X-TorBrowser-ExecShell=./Browser/start-tor-browser --detach
Icon=tor
StartupWMClass=Tor Browser
Path=
Terminal=false
StartupNotify=false
" > $HOME/Desktop/tor.desktop

chmod +x $HOME/Desktop/tor.desktop
cp $HOME/Desktop/tor.desktop $PREFIX/share/applications/tor.desktop
