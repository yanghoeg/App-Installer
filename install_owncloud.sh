#!/data/data/com.termux/files/usr/bin/bash
# ownCloud 데스크탑 클라이언트 — proot 내부 설치

set -euo pipefail

CONFIG="$HOME/.config/termux-xfce/config"
[ -f "$CONFIG" ] && source "$CONFIG"
PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
PROOT_USER="${PROOT_USER:-$(basename "$PREFIX/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/"* 2>/dev/null || echo "user")}"

_prun() { proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" --shared-tmp -- env DISPLAY=:1.0 "$@"; }

_prun sudo apt install -y software-properties-common
_prun sudo add-apt-repository -y ppa:nextcloud-devs/client
_prun sudo apt update
_prun sudo apt install -y owncloud-client

ROOTFS="${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}"
mkdir -p "$HOME/Desktop" "${PREFIX}/share/applications"

cp "${ROOTFS}/usr/share/applications/owncloud.desktop" "${PREFIX}/share/applications/owncloud.desktop"
sed -i "s/^Name=.*/Name=ownCloud/" "${PREFIX}/share/applications/owncloud.desktop"
sed -i "s|^Exec=\(.*\)$|Exec=prun QT_SCALE_FACTOR=2 owncloud|" "${PREFIX}/share/applications/owncloud.desktop"

cp "${PREFIX}/share/applications/owncloud.desktop" "$HOME/Desktop/owncloud.desktop"
chmod +x "$HOME/Desktop/owncloud.desktop"
