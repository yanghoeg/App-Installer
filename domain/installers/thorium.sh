#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Thorium Browser — proot 내부 설치
# arm64 .deb 직접 추출 방식 (AUR thorium은 x86 only, Ubuntu apt도 충돌)

_THORIUM_DEB_URL="https://github.com/Alex313031/Thorium-Raspi/releases/download/M124.0.6367.218/thorium-browser_124.0.6367.218_arm64.deb"

app_install_thorium() {
    # arm64 .deb에서 바이너리 직접 추출 — distro 무관하게 동작
    proot_exec sudo bash -c "
        curl -fsSL '${_THORIUM_DEB_URL}' -o /tmp/thorium.deb
        cd /tmp && ar x thorium.deb 2>/dev/null || dpkg --force-depends -i thorium.deb
        [ -f data.tar.* ] && tar -xf data.tar.* -C / || true
        rm -f /tmp/thorium.deb /tmp/control.tar.* /tmp/data.tar.* /tmp/debian-binary
        which thorium-browser || dpkg --force-depends -i /tmp/thorium.deb 2>/dev/null || true
    " 2>/dev/null || \
    proot_exec sudo bash -c "
        curl -fsSL '${_THORIUM_DEB_URL}' -o /tmp/thorium.deb
        dpkg --force-depends -i /tmp/thorium.deb
        rm -f /tmp/thorium.deb
    "

    desktop_register "thorium-browser" "Thorium" \
        'bash -c "prun thorium-browser --no-sandbox </dev/null >/dev/null 2>&1 &"' \
        "thorium-browser" "Network;"
}

app_remove_thorium() {
    proot_pkg_remove thorium-browser 2>/dev/null || true
    desktop_remove "thorium-browser"
}

app_is_installed_thorium() {
    desktop_is_registered "thorium-browser"
}
