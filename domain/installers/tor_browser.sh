#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Tor Browser — 공식 Linux ARM64 빌드 없음

app_install_tor_browser() {
    echo "[ERROR] 유지보수 중인 공식 Linux ARM64 빌드를 확인할 수 없어 신규 설치를 중단했습니다. Android 버전: https://www.torproject.org/download/#android" >&2
    return 1
}

app_remove_tor_browser() {
    proot_exec sudo rm -rf /opt/tor-browser || return 1
    desktop_remove "tor"
}

app_is_installed_tor_browser() {
    desktop_is_registered "tor"
}
