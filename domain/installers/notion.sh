#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Notion — proot 내부 AppImage
# zlib 패키지명 차이(zlib1g-dev vs zlib)는 adapter가 흡수

# 버전 핀 + sha256 — 버전을 올릴 때 sha256sum으로 상수를 갱신할 것.
_NOTION_VER="2.0.18-1"
_NOTION_URL="https://github.com/notion-enhancer/notion-repackaged/releases/download/v${_NOTION_VER}/Notion-${_NOTION_VER}-arm64.AppImage"
_NOTION_SHA256="eb3138238ad55ab08b54d5af2b2c817fd63af08a982376668f98d13eaa693a44"

app_install_notion() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    proot_pkg_install_zlib || return 1

    proot_exec bash -c "$(fetch_verified_src)"$'\n''
        set -e
        appimage="Notion-$3-arm64.AppImage"
        fetch_verified "$1" "$appimage" "$2"
        chmod +x "$appimage"
        "./$appimage" --appimage-extract
        rm -rf notion
        mv squashfs-root notion
        rm -f "$appimage"
    ' _ "$_NOTION_URL" "$_NOTION_SHA256" "$_NOTION_VER" || { echo "[ERROR] Notion 다운로드/설치 실패" >&2; return 1; }

    desktop_register "notion" "Notion" \
        "bash -c \"prun env MESA_LOADER_DRIVER_OVERRIDE=zink /home/${PROOT_USER}/notion/notion-app --no-sandbox </dev/null >/dev/null 2>&1 &\"" \
        "notion" "Office;"
}

app_remove_notion() {
    proot_exec rm -rf notion 2>/dev/null || true
    desktop_remove "notion"
}

app_is_installed_notion() {
    desktop_is_registered "notion"
}
