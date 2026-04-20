#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: Sumatra PDF — Wine 앱 (GPLv3)
# =============================================================================
# 경량 PDF/EPUB/MOBI/CHM/CBZ 뷰어

_SUMATRA_DESKTOP="${PREFIX}/share/applications/sumatrapdf.desktop"
_SUMATRA_WIN_PATH='C:\Program Files\SumatraPDF\SumatraPDF.exe'

# GitHub Releases에서 최신 x64 installer URL 조회
_sumatrapdf_installer_url() {
    local tag ver
    tag=$(curl -sf "https://api.github.com/repos/sumatrapdfreader/sumatrapdf/releases/latest" \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4 || echo "3.5.2")
    ver="${tag#v}"
    echo "https://github.com/sumatrapdfreader/sumatrapdf/releases/download/${tag}/SumatraPDF-${ver}-64-install.exe"
}

app_install_sumatrapdf() {
    if ! app_is_installed_wine; then
        echo "[Sumatra PDF] Wine이 필요합니다. 먼저 설치합니다."
        app_install_wine
    fi

    local url
    url=$(_sumatrapdf_installer_url)

    echo "[Sumatra PDF] 다운로드 및 설치 중..."
    proot_exec_wine bash -c "
        wget -q '${url}' -O /tmp/sumatra_install.exe || \
            curl -fsSL '${url}' -o /tmp/sumatra_install.exe
        echo '[Sumatra PDF] 설치 중 (silent)...'
        WINEDEBUG=-all wine /tmp/sumatra_install.exe -s -all-users 2>/dev/null || true
        rm -f /tmp/sumatra_install.exe
    "

    _sumatrapdf_create_launcher

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Sumatra PDF 설치 완료"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

_sumatrapdf_create_launcher() {
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
    gio set "${HOME}/Desktop/sumatrapdf.desktop" metadata::trusted true 2>/dev/null || true
}

app_remove_sumatrapdf() {
    proot_exec_wine bash -c "
        rm -rf \"\$HOME/.wine/drive_c/Program Files/SumatraPDF\" 2>/dev/null
    " 2>/dev/null || true
    rm -f "$_SUMATRA_DESKTOP" "${HOME}/Desktop/sumatrapdf.desktop"
}

app_is_installed_sumatrapdf() {
    [ -e "$_SUMATRA_DESKTOP" ]
}
