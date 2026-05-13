#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: 밝기 조절 — termux-brightness + XFCE 패널 런처

_BRIGHTNESS_SCRIPT="$PREFIX/bin/brightness-ctrl"
_BRIGHTNESS_DESKTOP="$PREFIX/share/applications/brightness-ctrl.desktop"

app_install_api_brightness() {
    cat > "$_BRIGHTNESS_SCRIPT" << 'BEOF'
#!/data/data/com.termux/files/usr/bin/bash
# 현재 밝기를 yad 슬라이더로 조절
VAL=$(yad --scale --title="밝기 조절" --text="화면 밝기" \
    --min-value=1 --max-value=255 --value=128 --step=5 \
    --width=350 --center 2>/dev/null) || exit 0
termux-brightness "$VAL"
BEOF
    chmod +x "$_BRIGHTNESS_SCRIPT"

    mkdir -p "$(dirname "$_BRIGHTNESS_DESKTOP")"
    cat > "$_BRIGHTNESS_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=밝기 조절
Exec=brightness-ctrl
Icon=display-brightness-symbolic
Categories=Settings;
Terminal=false
EOF
}

app_remove_api_brightness() {
    rm -f "$_BRIGHTNESS_SCRIPT" "$_BRIGHTNESS_DESKTOP"
}

app_is_installed_api_brightness() {
    [ -x "$_BRIGHTNESS_SCRIPT" ]
}
