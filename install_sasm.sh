#!/data/data/com.termux/files/usr/bin/bash
# SASM — proot 내부 어셈블러 IDE
# 주의: sasm은 Ubuntu 특정 codename repo 의존 — noble 이상은 mantic 폴백 사용

set -euo pipefail

CONFIG="$HOME/.config/termux-xfce/config"
[ -f "$CONFIG" ] && source "$CONFIG"
PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
PROOT_USER="${PROOT_USER:-$(basename "$PREFIX/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/"* 2>/dev/null || echo "user")}"

_prun() { proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" --shared-tmp -- env DISPLAY=:1.0 "$@"; }

ROOTFS="${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}"
SOURCES_LIST="${ROOTFS}/etc/apt/sources.list"

# sources.list codename 교체 (noble → mantic 폴백, 백업 후 수정)
if [ -f "$SOURCES_LIST" ]; then
    cp "${SOURCES_LIST}" "${SOURCES_LIST}.bak"
    sed -i 's/noble/mantic/g' "$SOURCES_LIST"
fi

_prun sudo apt update
_prun sudo apt install -y sasm

# alias 추가 (중복 방지)
local bashrc="${ROOTFS}/home/${PROOT_USER}/.bashrc"
grep -q "alias sasm=" "$bashrc" 2>/dev/null || \
    echo "alias sasm='QT_SCALE_FACTOR=2 sasm'" >> "$bashrc"

# sources.list 복원
[ -f "${SOURCES_LIST}.bak" ] && mv "${SOURCES_LIST}.bak" "$SOURCES_LIST"

mkdir -p "$HOME/Desktop" "${PREFIX}/share/applications"

cat > "$HOME/Desktop/sasm.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=SASM
GenericName=Simple assembler IDE
Comment=Simple crossplatform IDE for NASM, MASM, GAS, FASM
Exec=prun QT_SCALE_FACTOR=2 sasm
Categories=Development;
Icon=sasm
Terminal=false
StartupNotify=false
EOF

chmod +x "$HOME/Desktop/sasm.desktop"
cp "$HOME/Desktop/sasm.desktop" "${PREFIX}/share/applications/sasm.desktop"
