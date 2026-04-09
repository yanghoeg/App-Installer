#!/data/data/com.termux/files/usr/bin/bash
# Notion — proot 내부 AppImage

set -euo pipefail

CONFIG="$HOME/.config/termux-xfce/config"
[ -f "$CONFIG" ] && source "$CONFIG"
PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
PROOT_USER="${PROOT_USER:-$(basename "$PREFIX/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/"* 2>/dev/null || echo "user")}"

_prun() { proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" --shared-tmp -- env DISPLAY=:1.0 "$@"; }

_prun sudo apt install -y zlib1g-dev
_prun wget https://github.com/notion-enhancer/notion-repackaged/releases/download/v2.0.18-1/Notion-2.0.18-1-arm64.AppImage
_prun chmod +x Notion-2.0.18-1-arm64.AppImage
_prun ./Notion-2.0.18-1-arm64.AppImage --appimage-extract
_prun mv squashfs-root notion
_prun rm -f Notion-2.0.18-1-arm64.AppImage

mkdir -p "$HOME/Desktop" "${PREFIX}/share/applications"

cat > "$HOME/Desktop/notion.desktop" << EOF
[Desktop Entry]
Version=1.0
Name=Notion
Exec=proot-distro login ${PROOT_DISTRO} --user ${PROOT_USER} --shared-tmp -- env DISPLAY=:1.0 GALLIUM_DRIVER=virpipe notion/./notion-app --no-sandbox
StartupNotify=true
Terminal=false
Icon=notion
Type=Application
Categories=Office;
EOF

chmod +x "$HOME/Desktop/notion.desktop"
cp "$HOME/Desktop/notion.desktop" "${PREFIX}/share/applications/notion.desktop"
