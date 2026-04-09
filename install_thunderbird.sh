#!/data/data/com.termux/files/usr/bin/bash
# Thunderbird — Termux native 패키지 (proot 불필요)

set -euo pipefail

pkg install -y thunderbird

mkdir -p "$HOME/Desktop" "${PREFIX}/share/applications"

cat > "$HOME/Desktop/thunderbird.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Name=Thunderbird
Comment=Email, news, RSS and more
Exec=thunderbird %u
Icon=thunderbird
Terminal=false
Type=Application
Categories=Network;Email;News;
MimeType=message/rfc822;x-scheme-handler/mailto;
StartupNotify=true
EOF

chmod +x "$HOME/Desktop/thunderbird.desktop"
cp "$HOME/Desktop/thunderbird.desktop" "${PREFIX}/share/applications/thunderbird.desktop"
