#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: WinMerge — Wine 앱 (GPLv2)
# =============================================================================
# 파일/폴더 비교·병합 도구
# NSIS installer는 Box64에서 실패 → portable zip 사용

_WINMERGE_DESKTOP="${PREFIX}/share/applications/winmerge.desktop"
_WINMERGE_WIN_PATH='C:\Program Files\WinMerge\WinMergeU.exe'

_winmerge_portable_url() {
    local tag ver
    tag=$(curl -sf "https://api.github.com/repos/WinMerge/winmerge/releases/latest" \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4 || echo "v2.16.56")
    ver="${tag#v}"
    echo "https://github.com/WinMerge/winmerge/releases/download/${tag}/WinMerge-${ver}-x64-exe.zip"
}

app_install_winmerge() {
    if ! wine_backend_available; then
        echo "[WinMerge] Wine이 필요합니다. 먼저 설치합니다."
        app_install_wine || return 1
    fi

    local url
    url=$(_winmerge_portable_url)

    echo "[WinMerge] portable zip 다운로드 및 설치 중... (백엔드: $(wine_backend))"
    wine_exec_shell "
        set -e
        wget -q '${url}' -O \${TMPDIR:-/tmp}/winmerge.zip || \
            curl -fsSL '${url}' -o \${TMPDIR:-/tmp}/winmerge.zip
        mkdir -p \"\$WINEPREFIX/drive_c/Program Files/WinMerge\"
        unzip -qo \${TMPDIR:-/tmp}/winmerge.zip -d \"\$WINEPREFIX/drive_c/Program Files/WinMerge/\"
        # zip 내 서브디렉토리가 있으면 한 단계 올림
        cd \"\$WINEPREFIX/drive_c/Program Files/WinMerge\"
        if [ -d WinMerge ]; then
            mv WinMerge/* . 2>/dev/null
            rmdir WinMerge 2>/dev/null || rm -rf WinMerge
        fi
        rm -f \${TMPDIR:-/tmp}/winmerge.zip
        test -e \"\$WINEPREFIX/drive_c/Program Files/WinMerge/WinMergeU.exe\"
    " || { echo "[ERROR] WinMerge 설치 실패" >&2; return 1; }

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

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  WinMerge 설치 완료"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

app_remove_winmerge() {
    wine_exec_shell "
        rm -rf \"\$WINEPREFIX/drive_c/Program Files/WinMerge\" 2>/dev/null
    " 2>/dev/null || true
    rm -f "$_WINMERGE_DESKTOP" "${HOME}/Desktop/winmerge.desktop"
}

app_is_installed_winmerge() {
    [ -e "$_WINMERGE_DESKTOP" ]
}
