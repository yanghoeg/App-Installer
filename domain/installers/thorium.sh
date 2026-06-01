#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Thorium Browser — proot 내부 설치
# arm64 .deb 직접 추출 방식 (AUR thorium은 x86 only, Ubuntu apt도 충돌)

_THORIUM_DEB_URL="https://github.com/Alex313031/Thorium-Raspi/releases/download/M124.0.6367.218/thorium-browser_124.0.6367.218_arm64.deb"

app_install_thorium() {
    # arm64 .deb에서 바이너리 직접 추출 — distro 무관하게 동작
    # Ubuntu 25.10: coreutils-from-uutils 충돌로 apt 불가 → dpkg --force-depends 폴백
    # Arch: pacman에 등록 안 됨 → ar로 수동 추출
    proot_exec sudo bash -c "
        curl -fsSL '${_THORIUM_DEB_URL}' -o /tmp/thorium.deb

        # ar 방식 시도 (binutils 필요)
        if command -v ar &>/dev/null; then
            mkdir -p /tmp/thorium-extract
            cd /tmp/thorium-extract
            ar x /tmp/thorium.deb
            data_tar=\$(ls data.tar.* 2>/dev/null | head -1)
            if [ -n \"\$data_tar\" ]; then
                tar -xf \"\$data_tar\" -C /
            fi
            cd / && rm -rf /tmp/thorium-extract
        else
            # ar 없으면 dpkg --force-depends (Ubuntu 전용)
            dpkg --force-depends -i /tmp/thorium.deb
        fi
        rm -f /tmp/thorium.deb
    "

    desktop_register "thorium-browser" "Thorium" \
        'bash -c "prun thorium-browser --no-sandbox </dev/null >/dev/null 2>&1 &"' \
        "thorium-browser" "Network;"
}

app_remove_thorium() {
    # .deb 추출 방식으로 설치했으므로 파일 직접 삭제 (pacman/apt 미등록)
    proot_exec sudo bash -c "
        rm -rf /opt/chromium.org/thorium
        rm -f /usr/bin/thorium-browser /usr/sbin/thorium-browser
        rm -f /usr/share/applications/thorium-browser.desktop
        rm -f /usr/share/icons/hicolor/*/apps/thorium-browser.png 2>/dev/null || true
    " 2>/dev/null || \
    proot_pkg_remove thorium-browser 2>/dev/null || true
    desktop_remove "thorium-browser"
}

app_is_installed_thorium() {
    desktop_is_registered "thorium-browser"
}
