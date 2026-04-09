#!/data/data/com.termux/files/usr/bin/bash
# Thorium Browser — proot 내부 deb 설치

set -euo pipefail

CONFIG="$HOME/.config/termux-xfce/config"
[ -f "$CONFIG" ] && source "$CONFIG"
PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
PROOT_USER="${PROOT_USER:-$(basename "$PREFIX/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/"* 2>/dev/null || echo "user")}"

appname="thorium-browser"
url="https://github.com/Alex313031/Thorium-Raspi/releases/download/M124.0.6367.218/thorium-browser_124.0.6367.218_arm64.deb"
deb="${url##*/}"

_prun() { proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" --shared-tmp -- env DISPLAY=:1.0 "$@"; }

# 인자 처리
install_flag=false; uninstall_flag=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --install)   install_flag=true;   shift ;;
        --uninstall) uninstall_flag=true; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [ "$install_flag" = true ]; then
    _prun wget "$url" -O "$deb"
    _prun sudo apt install -y "./$deb"
    _prun rm -f "$deb"

    mkdir -p "$HOME/Desktop" "${PREFIX}/share/applications"
    desktop_file="$HOME/Desktop/${appname}.desktop"

    cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Thorium
Comment=The fastest browser on Earth
Exec=prun ${appname} --no-sandbox
Icon=${appname}
Categories=Network;
Terminal=false
EOF

    chmod +x "$desktop_file"
    cp "$desktop_file" "${PREFIX}/share/applications/${appname}.desktop"
    echo "Installation completed."

elif [ "$uninstall_flag" = true ]; then
    _prun sudo apt remove -y "$appname"
    rm -f "$HOME/Desktop/${appname}.desktop" "${PREFIX}/share/applications/${appname}.desktop"
    echo "Uninstallation completed."
else
    echo "No valid option provided. Use --install or --uninstall." >&2
    exit 1
fi
