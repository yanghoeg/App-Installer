#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: 배경화면 동기화 — XFCE 배경화면을 Android에 적용

_WALLSYNC_SCRIPT="$PREFIX/bin/wallpaper-sync"
_WALLSYNC_DESKTOP="$PREFIX/share/applications/wallpaper-sync.desktop"

app_install_api_wallpaper() {
    cat > "$_WALLSYNC_SCRIPT" << 'WEOF'
#!/data/data/com.termux/files/usr/bin/bash
# XFCE 현재 배경화면을 Android 배경으로 동기화
XFCE_WP=$(xfconf-query -c xfce4-desktop \
    -p /backdrop/screen0/monitorscreen0/workspace0/last-image 2>/dev/null || \
    xfconf-query -c xfce4-desktop \
    -p /backdrop/screen0/monitor0/workspace0/last-image 2>/dev/null)

if [ -z "$XFCE_WP" ] || [ ! -f "$XFCE_WP" ]; then
    yad --error --title="배경화면 동기화" \
        --text="XFCE 배경화면을 찾을 수 없습니다." \
        --center --width=350 2>/dev/null
    exit 1
fi

termux-wallpaper -f "$XFCE_WP" && \
    yad --info --title="배경화면 동기화" \
        --text="Android 배경화면이 동기화되었습니다.\n\n${XFCE_WP}" \
        --center --width=400 2>/dev/null
WEOF
    chmod +x "$_WALLSYNC_SCRIPT"

    mkdir -p "$(dirname "$_WALLSYNC_DESKTOP")"
    cat > "$_WALLSYNC_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=배경화면 동기화
Comment=XFCE 배경화면을 Android에 적용
Exec=wallpaper-sync
Icon=preferences-desktop-wallpaper-symbolic
Categories=Settings;
Terminal=false
EOF
}

app_remove_api_wallpaper() {
    rm -f "$_WALLSYNC_SCRIPT" "$_WALLSYNC_DESKTOP"
}

app_is_installed_api_wallpaper() {
    [ -x "$_WALLSYNC_SCRIPT" ]
}
