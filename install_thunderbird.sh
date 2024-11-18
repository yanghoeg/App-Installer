#!/data/data/com.termux/files/usr/bin/bash

pkg update
pkg upgrade -y
pkg install thunderbird

# Create the desktop entry
echo "[Desktop Entry]
Type=Application
Name=Thunderbird
GenericName=thunderbird
Comment=Thunderbird mail
Exec=thunderbird
Categories=Office;
Icon=Thunderbird
Path=
Terminal=true
StartupNotify=false
" > $HOME/Desktop/thunderbird.desktop

chmod +x $HOME/Desktop/thunderbird.desktop
cp $HOME/Desktop/thunderbird.desktop $PREFIX/share/applications/thunderbird.desktop
