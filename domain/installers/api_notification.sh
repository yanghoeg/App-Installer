#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: 알림 도구 — termux-notification 래퍼 + XFCE 메뉴 등록

_NOTIFY_SCRIPT="$PREFIX/bin/tnotify"
_NOTIFY_DESKTOP="$PREFIX/share/applications/tnotify.desktop"

app_install_api_notification() {
    cat > "$_NOTIFY_SCRIPT" << 'NEOF'
#!/data/data/com.termux/files/usr/bin/bash
# 사용법: tnotify "제목" "내용"  또는  tnotify (GUI 입력)
if [ $# -ge 2 ]; then
    termux-notification -t "$1" -c "$2"
elif [ $# -eq 1 ]; then
    termux-notification -t "$1"
else
    INPUT=$(yad --form --title="알림 보내기" \
        --field="제목" "" \
        --field="내용" "" \
        --width=400 --center 2>/dev/null) || exit 0
    TITLE=$(echo "$INPUT" | cut -d'|' -f1)
    BODY=$(echo "$INPUT" | cut -d'|' -f2)
    [ -n "$TITLE" ] && termux-notification -t "$TITLE" -c "$BODY"
fi
NEOF
    chmod +x "$_NOTIFY_SCRIPT"

    mkdir -p "$(dirname "$_NOTIFY_DESKTOP")"
    cat > "$_NOTIFY_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=알림 보내기
Comment=Android 알림바에 알림 전송
Exec=tnotify
Icon=notification-symbolic
Categories=Utility;
Terminal=false
EOF
}

app_remove_api_notification() {
    rm -f "$_NOTIFY_SCRIPT" "$_NOTIFY_DESKTOP"
}

app_is_installed_api_notification() {
    [ -x "$_NOTIFY_SCRIPT" ]
}
