#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Notion — proot 내부 AppImage
# zlib 패키지명 차이(zlib1g-dev vs zlib)는 adapter가 흡수

app_install_notion() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    proot_pkg_install_zlib || return 1

    proot_exec bash -c "
        set -e
        wget -O Notion-2.0.18-1-arm64.AppImage https://github.com/notion-enhancer/notion-repackaged/releases/download/v2.0.18-1/Notion-2.0.18-1-arm64.AppImage
        chmod +x Notion-2.0.18-1-arm64.AppImage
        ./Notion-2.0.18-1-arm64.AppImage --appimage-extract
        mv squashfs-root notion
        rm -f Notion-2.0.18-1-arm64.AppImage
    " || { echo "[ERROR] Notion 다운로드/설치 실패" >&2; return 1; }

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
