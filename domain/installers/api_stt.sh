#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: 음성인식 — termux-speech-to-text 래퍼 + XFCE 메뉴 등록

_STT_SCRIPT="$PREFIX/bin/stt-recognize"
_STT_DESKTOP="$PREFIX/share/applications/stt-recognize.desktop"

app_install_api_stt() {
    cat > "$_STT_SCRIPT" << 'SEOF'
#!/data/data/com.termux/files/usr/bin/bash
# 사용법: stt-recognize          (GUI — 인식 결과를 클립보드에 복사)
#         stt-recognize --raw     (raw 출력)
#         stt-recognize --debug   (디버그 — raw 출력을 파일에 저장)
if [ "${1:-}" = "--raw" ]; then
    termux-speech-to-text
    exit $?
fi
if [ "${1:-}" = "--debug" ]; then
    termux-speech-to-text > /tmp/stt_debug.txt 2>&1
    echo "=== raw output ===" && cat -A /tmp/stt_debug.txt
    exit 0
fi
TMPF=$(mktemp)
termux-speech-to-text > "$TMPF" 2>/dev/null
TEXT=$(sed '/^$/d' "$TMPF" | tail -1)
rm -f "$TMPF"
if [ -z "$TEXT" ]; then
    yad --error --title="음성인식" \
        --text="음성을 인식하지 못했습니다.\n\n디버그: stt-recognize --debug" \
        --center --width=400 2>/dev/null
    exit 1
fi
printf '%s' "$TEXT" | xclip -selection clipboard 2>/dev/null
yad --info --title="음성인식" \
    --text="인식 결과 (클립보드에 복사됨):\n\n${TEXT}" \
    --center --width=450 2>/dev/null
SEOF
    chmod +x "$_STT_SCRIPT"

    mkdir -p "$(dirname "$_STT_DESKTOP")"
    cat > "$_STT_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=음성인식
Comment=음성을 텍스트로 변환 (Android STT)
Exec=stt-recognize
Icon=audio-input-microphone-symbolic
Categories=Utility;
Terminal=false
EOF
}

app_remove_api_stt() {
    rm -f "$_STT_SCRIPT" "$_STT_DESKTOP"
}

app_is_installed_api_stt() {
    [ -x "$_STT_SCRIPT" ]
}
