#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Microsoft Teams — teams-for-linux (커뮤니티 Electron)
# Ubuntu: GitHub arm64 .deb / Arch: AUR teams-for-linux → adapter가 처리

app_install_teams() {
    proot_pkg_update
    proot_pkg_install curl

    local latest_url
    latest_url=$(proot_exec curl -fsSL \
        "https://api.github.com/repos/IsmaelMartinez/teams-for-linux/releases/latest" \
        | grep "browser_download_url" \
        | grep "arm64\.deb" \
        | head -1 \
        | sed 's/.*"browser_download_url": "\(.*\)"/\1/' \
        | tr -d '"')

    if [ -z "$latest_url" ]; then
        echo "[ERROR] arm64 .deb 다운로드 URL을 찾을 수 없습니다." >&2
        return 1
    fi

    proot_pkg_install_deb_or_aur "$latest_url" "teams-for-linux"

    desktop_register "teams" "Microsoft Teams" "prun teams-for-linux --no-sandbox" \
        "teams-for-linux" "Network;InstantMessaging;"
}

app_remove_teams() {
    proot_pkg_remove teams-for-linux 2>/dev/null || true
    proot_pkg_autoremove
    desktop_remove "teams"
}

app_is_installed_teams() {
    desktop_is_registered "teams"
}
