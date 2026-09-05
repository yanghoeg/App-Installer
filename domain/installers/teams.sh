#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Microsoft Teams — teams-for-linux (커뮤니티 Electron)
# Ubuntu: GitHub arm64 .deb / Arch: AUR teams-for-linux → adapter가 처리

# 버전 핀 + sha256 (GitHub API latest 조회 없음) — 버전을 올릴 때 sha256sum으로 갱신할 것.
_TEAMS_VER="2.18.1"
_TEAMS_DEB_URL="https://github.com/IsmaelMartinez/teams-for-linux/releases/download/v${_TEAMS_VER}/teams-for-linux_${_TEAMS_VER}_arm64.deb"
_TEAMS_DEB_SHA256="4e7d0de6f671ed133284961be61b15228db6f857cfdadb407b4a5331a308bf55"

app_install_teams() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    proot_pkg_update || return 1

    proot_pkg_install_deb_or_aur "$_TEAMS_DEB_URL" "teams-for-linux" "$_TEAMS_DEB_SHA256" \
        || { echo "[ERROR] Teams 설치 실패" >&2; return 1; }

    desktop_register "teams" "Microsoft Teams" \
        'bash -c "prun teams-for-linux --no-sandbox </dev/null >/dev/null 2>&1 &"' \
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
