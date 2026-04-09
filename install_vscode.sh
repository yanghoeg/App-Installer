#!/data/data/com.termux/files/usr/bin/bash
# Visual Studio Code — proot 내부 deb 설치 (Microsoft 공식 arm64)

set -euo pipefail

CONFIG="$HOME/.config/termux-xfce/config"
[ -f "$CONFIG" ] && source "$CONFIG"
PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
PROOT_USER="${PROOT_USER:-$(basename "$PREFIX/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/"* 2>/dev/null || echo "user")}"

_prun() { proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" --shared-tmp -- env DISPLAY=:1.0 "$@"; }

# 기존 설치 제거 후 재설치
_prun sudo apt purge -y code 2>/dev/null || true
_prun sudo apt update

# Microsoft 서명 키 + repo 추가 (최초 1회)
_prun sudo bash -c "
    apt install -y gpg software-properties-common apt-transport-https 2>/dev/null
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft.gpg
    echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main' \
        > /etc/apt/sources.list.d/vscode.list
    apt update
"

# repo로 설치 (최신 버전 자동 선택)
_prun sudo apt install -y code

mkdir -p "$HOME/Desktop" "${PREFIX}/share/applications"

cat > "$HOME/Desktop/code.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Visual Studio Code
Comment=Code Editing. Redefined.
Exec=prun code --no-sandbox
Icon=visual-studio-code
Categories=Development;
Terminal=false
StartupNotify=false
EOF

chmod +x "$HOME/Desktop/code.desktop"
cp "$HOME/Desktop/code.desktop" "${PREFIX}/share/applications/code.desktop"
