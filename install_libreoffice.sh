#!/data/data/com.termux/files/usr/bin/bash
# LibreOffice — proot 내부 설치 후 Termux 메뉴에 등록

set -euo pipefail

CONFIG="$HOME/.config/termux-xfce/config"
[ -f "$CONFIG" ] && source "$CONFIG"
PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
PROOT_USER="${PROOT_USER:-$(basename "$PREFIX/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/"* 2>/dev/null || echo "user")}"

_prun() { proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" --shared-tmp -- env DISPLAY=:1.0 "$@"; }

_prun sudo apt update
_prun sudo apt install -y libreoffice

# proot 내 desktop 파일들을 Termux share/applications로 복사 + Exec 재작성
ROOTFS="${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}"
mkdir -p "${PREFIX}/share/applications"

for desktop in "${ROOTFS}/usr/share/applications"/libreoffice*.desktop; do
    [ -f "$desktop" ] || continue
    fname=$(basename "$desktop")
    cp "$desktop" "${PREFIX}/share/applications/${fname}"
    sed -i "s|^Exec=\(.*\)$|Exec=proot-distro login ${PROOT_DISTRO} --user ${PROOT_USER} --shared-tmp -- env DISPLAY=:1.0 \1|" \
        "${PREFIX}/share/applications/${fname}"
done
