#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: KakaoTalk — Wine 앱
# =============================================================================

_KAKAOTALK_DESKTOP="${PREFIX}/share/applications/kakaotalk.desktop"
_KAKAOTALK_URL="https://app-pc.kakaocdn.net/talk/win32/KakaoTalk_Setup.exe"

app_install_kakaotalk() {
    if ! app_is_installed_wine; then
        echo "[KakaoTalk] Wine이 필요합니다. 먼저 설치합니다."
        app_install_wine
    fi

    echo "[KakaoTalk] 다운로드 및 설치 중..."
    proot_exec_wine bash -c "
        wget -q '${_KAKAOTALK_URL}' -O /tmp/kakaotalk_setup.exe || \
            curl -fsSL '${_KAKAOTALK_URL}' -o /tmp/kakaotalk_setup.exe
        echo '[KakaoTalk] 설치 중 (silent)...'
        WINEDEBUG=-all wine /tmp/kakaotalk_setup.exe /S 2>/dev/null || true
        rm -f /tmp/kakaotalk_setup.exe
    "

    desktop_register "kakaotalk" "KakaoTalk" \
        'bash -c "wine '\''C:\\Program Files\\Kakao\\KakaoTalk\\KakaoTalk.exe'\'' </dev/null >/dev/null 2>&1 &"' \
        "wine" "Network;InstantMessaging;"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  KakaoTalk 설치 완료"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

app_remove_kakaotalk() {
    proot_exec_wine bash -c "
        rm -rf \"\$HOME/.wine/drive_c/Program Files/Kakao\" 2>/dev/null
    " 2>/dev/null || true
    desktop_remove "kakaotalk"
}

app_is_installed_kakaotalk() {
    desktop_is_registered "kakaotalk"
}
