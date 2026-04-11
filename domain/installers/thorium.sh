#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Thorium Browser — proot 내부 설치
# Ubuntu: arm64 .deb / Arch: AUR thorium-browser → adapter가 처리

_THORIUM_DEB_URL="https://github.com/Alex313031/Thorium-Raspi/releases/download/M124.0.6367.218/thorium-browser_124.0.6367.218_arm64.deb"

app_install_thorium() {
    proot_pkg_install_deb_or_aur "$_THORIUM_DEB_URL" "thorium-browser"

    desktop_register "thorium-browser" "Thorium" "prun thorium-browser --no-sandbox" \
        "thorium-browser" "Network;"
}

app_remove_thorium() {
    proot_pkg_remove thorium-browser 2>/dev/null || true
    desktop_remove "thorium-browser"
}

app_is_installed_thorium() {
    desktop_is_registered "thorium-browser"
}
