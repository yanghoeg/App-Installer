#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: Sumatra PDF — Wine 앱 (GPLv3)
# =============================================================================
# 경량 PDF/EPUB/MOBI/CHM/CBZ 뷰어
# portable single-exe 방식 (installer 불필요)

_SUMATRA_DESKTOP="${PREFIX}/share/applications/sumatrapdf.desktop"
_SUMATRA_WIN_PATH='C:\Program Files\SumatraPDF\SumatraPDF.exe'

_SUMATRA_VER="3.6.1"
_SUMATRA_SHA256="98b33a518d42986856d225064b0cd2d3643ecf78cbf84ab873d26cc51877a544"

_sumatrapdf_portable_url() {
    local ver="${1:-${_SUMATRA_VER}}"
    echo "https://www.sumatrapdfreader.org/dl/rel/${ver}/SumatraPDF-${ver}-64.zip"
}

app_install_sumatrapdf() {
    if ! wine_backend_available; then
        echo "[Sumatra PDF] Wine이 필요합니다. 먼저 설치합니다."
        app_install_wine || return 1
    fi

    local context
    context=$(wine_backend_context) || return 1

    echo "[Sumatra PDF] portable exe 다운로드 중... (백엔드: $(wine_backend))"
    wine_exec_shell "$(fetch_verified_src)"$'\n'"
        set -e
        mkdir -p \"\$WINEPREFIX/drive_c/Program Files/SumatraPDF\"
        fetch_verified '$(_sumatrapdf_portable_url)' \${TMPDIR:-/tmp}/sumatra.zip '${_SUMATRA_SHA256}'
        unzip -qo \${TMPDIR:-/tmp}/sumatra.zip -d \"\$WINEPREFIX/drive_c/Program Files/SumatraPDF/\"
        # zip 안의 파일명을 SumatraPDF.exe로 통일
        cd \"\$WINEPREFIX/drive_c/Program Files/SumatraPDF\"
        for f in SumatraPDF-*.exe; do
            [ -f \"\$f\" ] && mv \"\$f\" SumatraPDF.exe
        done
        [ -f \"\$WINEPREFIX/drive_c/Program Files/SumatraPDF/SumatraPDF.exe\" ]
        rm -f \${TMPDIR:-/tmp}/sumatra.zip
    " "$context" || { echo "[ERROR] Sumatra PDF 다운로드/설치 실패" >&2; return 1; }

    wine_app_record "sumatrapdf" "$context" || return 1

    mkdir -p "${PREFIX}/share/applications"
    cat > "$_SUMATRA_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Sumatra PDF
Comment=PDF/EPUB/MOBI 뷰어 (Wine)
Exec=wine-app-sumatrapdf %f
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
    wine_app_remove "sumatrapdf"
}

app_is_installed_sumatrapdf() {
    wine_app_is_installed "sumatrapdf"
}
