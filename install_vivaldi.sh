#!/data/data/com.termux/files/usr/bin/bash
varname=$(basename $PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu/home/*)

proot-distro login ubuntu --shared-tmp -- env DISPLAY=:1.0 apt update
proot-distro login ubuntu --shared-tmp -- env DISPLAY=:1.0 wget https://downloads.vivaldi.com/stable/vivaldi-stable_6.0.2979.22-1_arm64.deb
proot-distro login ubuntu --shared-tmp -- env DISPLAY=:1.0  sudo -S apt install ./vivaldi-stable_6.0.2979.22-1_arm64.deb -y
proot-distro login ubuntu --shared-tmp -- env DISPLAY=:1.0 rm vivaldi-stable_6.0.2979.22-1_arm64.deb
proot-distro login ubuntu --shared-tmp -- env DISPLAY=:1.0  apt-mark hold vivaldi-stable

echo "[Desktop Entry]
Name=Vivaldi
GenericName=Web Browser
Exec=proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0 vivaldi --no-sandbox
StartupNotify=true
Terminal=false
Icon=vivaldi
Type=Application
Categories=Network;WebBrowser;
MimeType=application/pdf;application/rdf+xml;application/rss+xml;application/xhtml+xml;application/xhtml_xml;application/xml;image/gif;image/jpeg;image/png;image/webp;text/html;text/xml;x-scheme-handler/ftp;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/mailto;
" > $HOME/Desktop/vivaldi.desktop

chmod +x $HOME/Desktop/vivaldi.desktop
cp $HOME/Desktop/vivaldi.desktop $PREFIX/share/applications/vivaldi.desktop 