#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: Sumatra PDF — Wine 앱 (GPLv3)
# =============================================================================
# 경량 PDF/EPUB/MOBI/CHM/CBZ 뷰어
# portable single-exe 방식 (installer 불필요)

_SUMATRA_DESKTOP="${PREFIX}/share/applications/sumatrapdf.desktop"
_SUMATRA_WIN_PATH='C:\Program Files\SumatraPDF\SumatraPDF.exe'

_sumatrapdf_portable_url() {
    local ver="${1:-3.5.2}"
    echo "https://www.sumatrapdfreader.org/dl/rel/${ver}/SumatraPDF-${ver}-64.zip"
}

app_install_sumatrapdf() {
    if ! wine_backend_available; then
        echo "[Sumatra PDF] Wine이 필요합니다. 먼저 설치합니다."
        app_install_wine || return 1
    fi

    echo "[Sumatra PDF] portable exe 다운로드 중... (백엔드: $(wine_backend))"
    wine_exec_shell "
        set -e
        mkdir -p \"\$WINEPREFIX/drive_c/Program Files/SumatraPDF\"
        wget -q '$(_sumatrapdf_portable_url)' -O /tmp/sumatra.zip || \
            curl -fsSL '$(_sumatrapdf_portable_url)' -o /tmp/sumatra.zip
        unzip -qo /tmp/sumatra.zip -d \"\$WINEPREFIX/drive_c/Program Files/SumatraPDF/\"
        # zip 안의 파일명을 SumatraPDF.exe로 통일
        cd \"\$WINEPREFIX/drive_c/Program Files/SumatraPDF\"
        for f in SumatraPDF-*.exe; do
            [ -f \"\$f\" ] && mv \"\$f\" SumatraPDF.exe
        done
        [ -f \"\$WINEPREFIX/drive_c/Program Files/SumatraPDF/SumatraPDF.exe\" ]
        rm -f /tmp/sumatra.zip
    " || { echo "[ERROR] Sumatra PDF 다운로드/설치 실패" >&2; return 1; }

    mkdir -p "${PREFIX}/share/applications"
    cat > "$_SUMATRA_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Sumatra PDF
Comment=PDF/EPUB/MOBI 뷰어 (Wine)
Exec=bash -c "wine 'C:\\Program Files\\SumatraPDF\\SumatraPDF.exe' %f </dev/null >/dev/null 2>&1 &"
Icon=wine
Categories=Office;Viewer;
MimeType=application/pdf;application/epub+zip;
Terminal=false
StartupNotify=false
EOF
    cp "$_SUMATRA_DESKTOP" "${HOME}/Desktop/sumatrapdf.desktop" 2>/dev/null || true
    chmod +x "${HOME}/Desktop/sumatrapdf.desktop" 2>/dev/null || true

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Sumatra PDF 설치 완료"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

app_remove_sumatrapdf() {
    wine_exec_shell "
        rm -rf \"\$WINEPREFIX/drive_c/Program Files/SumatraPDF\" 2>/dev/null
    " 2>/dev/null || true
    rm -f "$_SUMATRA_DESKTOP" "${HOME}/Desktop/sumatrapdf.desktop"
}

app_is_installed_sumatrapdf() {
    [ -e "$_SUMATRA_DESKTOP" ]
}
