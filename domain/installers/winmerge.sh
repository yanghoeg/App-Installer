#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: WinMerge — Wine 앱 (GPLv2)
# =============================================================================
# 파일/폴더 비교·병합 도구

_WINMERGE_DESKTOP="${PREFIX}/share/applications/winmerge.desktop"
_WINMERGE_WIN_PATH='C:\Program Files\WinMerge\WinMergeU.exe'

# GitHub Releases에서 최신 x64 installer URL 조회
_winmerge_installer_url() {
    local tag ver
    tag=$(curl -sf "https://api.github.com/repos/WinMerge/winmerge/releases/latest" \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4 || echo "v2.16.44")
    ver="${tag#v}"
    echo "https://github.com/WinMerge/winmerge/releases/download/${tag}/WinMerge-${ver}-x64-Setup.exe"
}

app_install_winmerge() {
    if ! app_is_installed_wine; then
        echo "[WinMerge] Wine이 필요합니다. 먼저 설치합니다."
        app_install_wine
    fi

    local url
    url=$(_winmerge_installer_url)

    echo "[WinMerge] 다운로드 및 설치 중..."
    proot_exec_wine bash -c "
        wget -q '${url}' -O /tmp/winmerge_install.exe || \
            curl -fsSL '${url}' -o /tmp/winmerge_install.exe
        echo '[WinMerge] 설치 중 (silent)...'
        WINEDEBUG=-all wine /tmp/winmerge_install.exe /VERYSILENT /SP- /NORESTART 2>/dev/null || true
        rm -f /tmp/winmerge_install.exe
    "

    _winmerge_create_launcher

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  WinMerge 설치 완료"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

_winmerge_create_launcher() {
    mkdir -p "${PREFIX}/share/applications"
    cat > "$_WINMERGE_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=WinMerge
Comment=파일/폴더 비교·병합 (Wine)
Exec=bash -c "wine 'C:\\Program Files\\WinMerge\\WinMergeU.exe' </dev/null >/dev/null 2>&1 &"
Icon=wine
Categories=Development;Utility;
Terminal=false
StartupNotify=false
EOF
    cp "$_WINMERGE_DESKTOP" "${HOME}/Desktop/winmerge.desktop" 2>/dev/null || true
    chmod +x "${HOME}/Desktop/winmerge.desktop" 2>/dev/null || true
    gio set "${HOME}/Desktop/winmerge.desktop" metadata::trusted true 2>/dev/null || true
}

app_remove_winmerge() {
    proot_exec_wine bash -c "
        WINEDEBUG=-all wine 'C:\\Program Files\\WinMerge\\unins000.exe' /VERYSILENT 2>/dev/null || \
        rm -rf \"\$HOME/.wine/drive_c/Program Files/WinMerge\" 2>/dev/null
    " 2>/dev/null || true
    rm -f "$_WINMERGE_DESKTOP" "${HOME}/Desktop/winmerge.desktop"
}

app_is_installed_winmerge() {
    [ -e "$_WINMERGE_DESKTOP" ]
}
