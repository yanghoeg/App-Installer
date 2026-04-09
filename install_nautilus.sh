#!/data/data/com.termux/files/usr/bin/bash
# Nautilus 파일 관리자 — proot 내부 설치

set -euo pipefail

CONFIG="$HOME/.config/termux-xfce/config"
[ -f "$CONFIG" ] && source "$CONFIG"
PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
PROOT_USER="${PROOT_USER:-$(basename "$PREFIX/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/"* 2>/dev/null || echo "user")}"

_prun() { proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" --shared-tmp -- env DISPLAY=:1.0 "$@"; }

_prun sudo apt update
_prun sudo apt install -y nautilus

ROOTFS="${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}"
mkdir -p "$HOME/Desktop" "${PREFIX}/share/applications"

cp "${ROOTFS}/usr/share/applications/nautilus.desktop" "${PREFIX}/share/applications/nautilus.desktop"
sed -i "s/^Exec=\(.*\)$/Exec=proot-distro login ${PROOT_DISTRO} --user ${PROOT_USER} --shared-tmp -- env DISPLAY=:1.0 \1/" \
    "${PREFIX}/share/applications/nautilus.desktop"

cp "${PREFIX}/share/applications/nautilus.desktop" "$HOME/Desktop/nautilus.desktop"
chmod +x "$HOME/Desktop/nautilus.desktop"
