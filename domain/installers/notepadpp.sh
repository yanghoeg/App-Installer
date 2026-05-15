#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: Notepad++ — Wine 앱
# =============================================================================

_NOTEPADPP_DESKTOP="${PREFIX}/share/applications/notepadpp.desktop"

_notepadpp_installer_url() {
    local tag ver
    tag=$(curl -sf "https://api.github.com/repos/notepad-plus-plus/notepad-plus-plus/releases/latest" \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4 || echo "v8.7.8")
    ver="${tag#v}"
    echo "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/${tag}/npp.${ver}.Installer.x64.exe"
}

app_install_notepadpp() {
    if ! app_is_installed_wine; then
        echo "[Notepad++] Wine이 필요합니다. 먼저 설치합니다."
        app_install_wine
    fi

    local url
    url=$(_notepadpp_installer_url)

    echo "[Notepad++] 다운로드 및 설치 중..."
    proot_exec_wine bash -c "
        wget -q '${url}' -O /tmp/npp_install.exe || \
            curl -fsSL '${url}' -o /tmp/npp_install.exe
        echo '[Notepad++] 설치 중 (silent)...'
        WINEDEBUG=-all wine /tmp/npp_install.exe /S 2>/dev/null || true
        rm -f /tmp/npp_install.exe
    "

    mkdir -p "${PREFIX}/share/applications"
    cat > "$_NOTEPADPP_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Notepad++
Comment=텍스트 에디터 (Wine)
Exec=bash -c "wine 'C:\\Program Files\\Notepad++\\notepad++.exe' %f </dev/null >/dev/null 2>&1 &"
Icon=wine
Categories=Development;TextEditor;
MimeType=text/plain;text/x-c;text/x-c++;text/x-java;application/xml;
Terminal=false
StartupNotify=false
EOF
    cp "$_NOTEPADPP_DESKTOP" "${HOME}/Desktop/notepadpp.desktop" 2>/dev/null || true
    chmod +x "${HOME}/Desktop/notepadpp.desktop" 2>/dev/null || true

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Notepad++ 설치 완료"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

app_remove_notepadpp() {
    proot_exec_wine bash -c "
        WINEDEBUG=-all wine 'C:\\Program Files\\Notepad++\\uninstall.exe' /S 2>/dev/null || \
        rm -rf \"\$HOME/.wine/drive_c/Program Files/Notepad++\" 2>/dev/null
    " 2>/dev/null || true
    rm -f "$_NOTEPADPP_DESKTOP" "${HOME}/Desktop/notepadpp.desktop"
}

app_is_installed_notepadpp() {
    [ -e "$_NOTEPADPP_DESKTOP" ]
}
