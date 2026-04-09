#!/data/data/com.termux/files/usr/bin/bash
# DBeaver CE — proot 내부 설치

set -euo pipefail

CONFIG="$HOME/.config/termux-xfce/config"
[ -f "$CONFIG" ] && source "$CONFIG"
PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
PROOT_USER="${PROOT_USER:-$(basename "$PREFIX/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/"* 2>/dev/null || echo "user")}"

_prun() { proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" --shared-tmp -- env DISPLAY=:1.0 "$@"; }

_prun sudo apt update
_prun sudo apt install -y openjdk-21-jdk 2>/dev/null || _prun sudo apt install -y openjdk-11-jdk
_prun wget "https://github.com/dbeaver/dbeaver/releases/download/24.3.1/dbeaver-ce-24.3.1-linux.gtk.aarch64-nojdk.tar.gz" -O dbeaver.tar.gz
_prun tar -xzf dbeaver.tar.gz
_prun sudo mv dbeaver /opt/
_prun sudo ln -sf /opt/dbeaver/dbeaver /usr/bin/dbeaver
_prun rm -f dbeaver.tar.gz

mkdir -p "$HOME/Desktop" "${PREFIX}/share/applications"

cat > "$HOME/Desktop/dbeaver.desktop" << EOF
[Desktop Entry]
Version=1.0
Name=DBeaver
Exec=proot-distro login ${PROOT_DISTRO} --user ${PROOT_USER} --shared-tmp -- env DISPLAY=:1.0 dbeaver --no-sandbox
StartupNotify=true
Terminal=false
Icon=dbeaver
Type=Application
Categories=Development;Database;
EOF

chmod +x "$HOME/Desktop/dbeaver.desktop"
cp "$HOME/Desktop/dbeaver.desktop" "${PREFIX}/share/applications/dbeaver.desktop"
