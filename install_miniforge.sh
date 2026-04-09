#!/data/data/com.termux/files/usr/bin/bash
# Miniforge3 — proot 내부 Python 환경

set -euo pipefail

CONFIG="$HOME/.config/termux-xfce/config"
[ -f "$CONFIG" ] && source "$CONFIG"
PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
PROOT_USER="${PROOT_USER:-$(basename "$PREFIX/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/"* 2>/dev/null || echo "user")}"

_prun() { proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" --shared-tmp -- env DISPLAY=:1.0 "$@"; }

_prun sudo apt update
_prun sudo apt install -y wget python3 python3-pip
# wget 하나만 (이중 wget 버그 수정)
_prun wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh
_prun chmod +x Miniforge3-Linux-aarch64.sh
_prun bash Miniforge3-Linux-aarch64.sh -b
_prun rm -f Miniforge3-Linux-aarch64.sh
