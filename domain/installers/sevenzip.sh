#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: 7-Zip — Wine 앱
# =============================================================================
# Wine /S 설치 시 기본 경로: C:\7-Zip (Program Files 아님)

_SEVENZIP_DESKTOP="${PREFIX}/share/applications/sevenzip.desktop"
_SEVENZIP_URL="https://www.7-zip.org/a/7z2601-x64.exe"
_SEVENZIP_SHA256="d64a0468f5b5b0b0fc5b2188450bcd655b70809d97b1c4535f2884635094377d"
_SEVENZIP_WIN_PATH='C:\7-Zip\7zFM.exe'

app_install_sevenzip() {
    if ! wine_backend_available; then
        echo "[7-Zip] Wine이 필요합니다. 먼저 설치합니다."
        app_install_wine || return 1
    fi

    echo "[7-Zip] 다운로드 및 설치 중... (백엔드: $(wine_backend))"
    wine_exec_shell "$(fetch_verified_src)"$'\n'"
        set -e
        fetch_verified '${_SEVENZIP_URL}' \${TMPDIR:-/tmp}/7z_install.exe '${_SEVENZIP_SHA256}'
        wine \${TMPDIR:-/tmp}/7z_install.exe /S 2>/dev/null || true
        rm -f \${TMPDIR:-/tmp}/7z_install.exe
        test -f \"\$WINEPREFIX/drive_c/7-Zip/7zFM.exe\"
    " || { echo "[ERROR] 7-Zip 설치 실패" >&2; return 1; }

    mkdir -p "${PREFIX}/share/applications"
    cat > "$_SEVENZIP_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=7-Zip
Comment=파일 압축/해제 (Wine)
Exec=bash -c "wine 'C:\\7-Zip\\7zFM.exe' %f </dev/null >/dev/null 2>&1 &"
Icon=wine
Categories=Utility;Archiving;
MimeType=application/zip;application/x-7z-compressed;application/gzip;application/x-tar;application/x-rar;
Terminal=false
StartupNotify=false
EOF
    cp "$_SEVENZIP_DESKTOP" "${HOME}/Desktop/sevenzip.desktop" 2>/dev/null || true
    chmod +x "${HOME}/Desktop/sevenzip.desktop" 2>/dev/null || true

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  7-Zip 설치 완료"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

app_remove_sevenzip() {
    wine_exec_shell "
        rm -rf \"\$WINEPREFIX/drive_c/7-Zip\" 2>/dev/null
    " 2>/dev/null || true
    rm -f "$_SEVENZIP_DESKTOP" "${HOME}/Desktop/sevenzip.desktop"
}

app_is_installed_sevenzip() {
    [ -e "$_SEVENZIP_DESKTOP" ]
}
