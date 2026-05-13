#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: TTS 음성 — termux-tts-speak 래퍼 + XFCE 메뉴 등록

_TTS_SCRIPT="$PREFIX/bin/tts-speak"
_TTS_DESKTOP="$PREFIX/share/applications/tts-speak.desktop"

app_install_api_tts() {
    cat > "$_TTS_SCRIPT" << 'TEOF'
#!/data/data/com.termux/files/usr/bin/bash
# 사용법: tts-speak "할 말"  또는  tts-speak (GUI 입력)
#         echo "텍스트" | tts-speak -  (파이프 입력)
if [ "$1" = "-" ]; then
    cat | termux-tts-speak
elif [ $# -ge 1 ]; then
    termux-tts-speak "$*"
else
    TEXT=$(yad --entry --title="TTS 음성 변환" \
        --text="읽을 텍스트를 입력하세요:" \
        --width=450 --center 2>/dev/null) || exit 0
    [ -n "$TEXT" ] && termux-tts-speak "$TEXT"
fi
TEOF
    chmod +x "$_TTS_SCRIPT"

    mkdir -p "$(dirname "$_TTS_DESKTOP")"
    cat > "$_TTS_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=TTS 음성
Comment=텍스트를 음성으로 변환 (Android TTS)
Exec=tts-speak
Icon=audio-speakers-symbolic
Categories=Utility;
Terminal=false
EOF
}

app_remove_api_tts() {
    rm -f "$_TTS_SCRIPT" "$_TTS_DESKTOP"
}

app_is_installed_api_tts() {
    [ -x "$_TTS_SCRIPT" ]
}
