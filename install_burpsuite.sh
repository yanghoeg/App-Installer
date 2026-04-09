#!/data/data/com.termux/files/usr/bin/bash
# BurpSuite Community — proot 내부 설치

set -euo pipefail

CONFIG="$HOME/.config/termux-xfce/config"
[ -f "$CONFIG" ] && source "$CONFIG"
PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
PROOT_USER="${PROOT_USER:-$(basename "$PREFIX/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/"* 2>/dev/null || echo "user")}"

_prun() { proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" --shared-tmp -- env DISPLAY=:1.0 "$@"; }

_prun sudo apt update
_prun curl -L -o burpsuite_community_linux_arm64.sh \
    'https://portswigger.net/burp/releases/startdownload?product=community&version=2024.11.2&type=linuxarm64'
_prun chmod +x burpsuite_community_linux_arm64.sh
_prun sudo ./burpsuite_community_linux_arm64.sh
_prun rm -f ./burpsuite_community_linux_arm64.sh

mkdir -p "$HOME/Desktop" "${PREFIX}/share/applications"

cat > "$HOME/Desktop/burpsuite.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Name=Burp Suite Community
Exec=prun BurpSuiteCommunity
StartupNotify=true
Terminal=true
Icon=burpsuite
Type=Application
Categories=Security;Network;
EOF

chmod +x "$HOME/Desktop/burpsuite.desktop"
cp "$HOME/Desktop/burpsuite.desktop" "${PREFIX}/share/applications/burpsuite.desktop"
