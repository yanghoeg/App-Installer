#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: WinMerge — Wine 앱 (GPLv2)
# =============================================================================
# 파일/폴더 비교·병합 도구
# NSIS installer는 Box64에서 실패 → portable zip 사용

_WINMERGE_DESKTOP="${PREFIX}/share/applications/winmerge.desktop"
_WINMERGE_WIN_PATH='C:\Program Files\WinMerge\WinMergeU.exe'

# 버전 핀 + sha256 (GitHub API latest 조회 없음). 에셋명은 소문자 winmerge-...
# 버전을 올릴 때: 새 zip을 받아 sha256sum으로 아래 상수를 갱신할 것.
_WINMERGE_VER="2.16.58.2"
_WINMERGE_SHA256="5732474add39283f44bd20c66e57503d26f435e695feabc4140ba2f91d2e7804"

_winmerge_portable_url() {
    echo "https://github.com/WinMerge/winmerge/releases/download/v${_WINMERGE_VER}/winmerge-${_WINMERGE_VER}-x64-exe.zip"
}

app_install_winmerge() {
    if ! wine_backend_available; then
        echo "[WinMerge] Wine이 필요합니다. 먼저 설치합니다."
        app_install_wine || return 1
    fi

    local url
    url=$(_winmerge_portable_url)

    echo "[WinMerge] portable zip 다운로드 및 설치 중... (백엔드: $(wine_backend))"
    wine_exec_shell "$(fetch_verified_src)"$'\n'"
        set -e
        fetch_verified '${url}' \${TMPDIR:-/tmp}/winmerge.zip '${_WINMERGE_SHA256}'
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
