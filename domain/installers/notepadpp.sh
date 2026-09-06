#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: Notepad++ — Wine 앱
# =============================================================================
# NSIS installer는 Box64에서 실패 → portable zip 사용

_NOTEPADPP_DESKTOP="${PREFIX}/share/applications/notepadpp.desktop"

# 버전 핀 + sha256 (GitHub API latest 조회 없음 — 재현 가능한 설치 + 무결성 검증)
# 버전을 올릴 때: 새 zip을 받아 sha256sum으로 아래 상수를 갱신할 것.
_NOTEPADPP_VER="8.9.8"
_NOTEPADPP_SHA256="b269383239464a945d17cfabfccf53935b83d80d907922310fdfd50d80274c66"

_notepadpp_portable_url() {
    echo "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v${_NOTEPADPP_VER}/npp.${_NOTEPADPP_VER}.portable.x64.zip"
}

app_install_notepadpp() {
    if ! wine_backend_available; then
        echo "[Notepad++] Wine이 필요합니다. 먼저 설치합니다."
        app_install_wine || return 1
    fi

    local url
    url=$(_notepadpp_portable_url)

    echo "[Notepad++] portable zip 다운로드 및 설치 중... (백엔드: $(wine_backend))"
    if ! wine_exec_shell "$(fetch_verified_src)"$'\n'"
        set -e
        fetch_verified '${url}' \${TMPDIR:-/tmp}/npp.zip '${_NOTEPADPP_SHA256}'
        mkdir -p \"\$WINEPREFIX/drive_c/Program Files/Notepad++\"
        unzip -qo \${TMPDIR:-/tmp}/npp.zip -d \"\$WINEPREFIX/drive_c/Program Files/Notepad++\"
        rm -f \${TMPDIR:-/tmp}/npp.zip
        [ -f \"\$WINEPREFIX/drive_c/Program Files/Notepad++/notepad++.exe\" ]
    "; then
        echo "[ERROR] Notepad++ 다운로드/설치 실패" >&2
        return 1
    fi

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
    wine_exec_shell "
        rm -rf \"\$WINEPREFIX/drive_c/Program Files/Notepad++\" 2>/dev/null
    " 2>/dev/null || true
    rm -f "$_NOTEPADPP_DESKTOP" "${HOME}/Desktop/notepadpp.desktop"
}

app_is_installed_notepadpp() {
    [ -e "$_NOTEPADPP_DESKTOP" ]
}
