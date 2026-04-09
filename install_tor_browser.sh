#!/data/data/com.termux/files/usr/bin/bash
# Tor Browser — proot 내부 설치 (arm64 포트)

set -euo pipefail

CONFIG="$HOME/.config/termux-xfce/config"
[ -f "$CONFIG" ] && source "$CONFIG"
PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
PROOT_USER="${PROOT_USER:-$(basename "$PREFIX/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/"* 2>/dev/null || echo "user")}"

_prun() { proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" --shared-tmp -- env DISPLAY=:1.0 "$@"; }

TOR_VER="13.0.9"
TOR_URL="https://sourceforge.net/projects/tor-browser-ports/files/${TOR_VER}/tor-browser-linux-arm64-${TOR_VER}.tar.xz/download"

_prun sudo apt install -y software-properties-common 2>/dev/null || true
_prun sudo apt update

# arm64 포트 tarball 다운로드 + 설치
_prun bash -c "
    curl -L '${TOR_URL}' -o tor.tar.xz
    tar -xJf tor.tar.xz
    mv tor-browser /opt/tor-browser
    rm -f tor.tar.xz
"

mkdir -p "$HOME/Desktop" "${PREFIX}/share/applications"

cat > "$HOME/Desktop/tor.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Tor Browser
GenericName=Web Browser
Comment=Tor Browser is +1 for privacy and -1 for mass surveillance
Categories=Network;WebBrowser;Security;
Exec=proot-distro login ${PROOT_DISTRO} --user ${PROOT_USER} --shared-tmp -- env DISPLAY=:1.0 /opt/tor-browser/Browser/start-tor-browser --no-sandbox
Icon=tor
StartupWMClass=Tor Browser
Terminal=false
StartupNotify=false
EOF

chmod +x "$HOME/Desktop/tor.desktop"
cp "$HOME/Desktop/tor.desktop" "${PREFIX}/share/applications/tor.desktop"
