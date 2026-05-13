#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: 볼륨 조절 — termux-volume + XFCE 패널 런처

_VOLUME_SCRIPT="$PREFIX/bin/volume-ctrl"
_VOLUME_DESKTOP="$PREFIX/share/applications/volume-ctrl.desktop"

app_install_api_volume() {
    cat > "$_VOLUME_SCRIPT" << 'VEOF'
#!/data/data/com.termux/files/usr/bin/bash
# 미디어 볼륨을 yad 슬라이더로 조절
MAX=$(termux-volume 2>/dev/null | jq -r '.[] | select(.stream=="music") | .max_volume')
CUR=$(termux-volume 2>/dev/null | jq -r '.[] | select(.stream=="music") | .volume')
VAL=$(yad --scale --title="볼륨 조절" --text="미디어 볼륨" \
    --min-value=0 --max-value="${MAX:-15}" --value="${CUR:-7}" --step=1 \
    --width=350 --center 2>/dev/null) || exit 0
termux-volume music "$VAL"
VEOF
    chmod +x "$_VOLUME_SCRIPT"

    mkdir -p "$(dirname "$_VOLUME_DESKTOP")"
    cat > "$_VOLUME_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=볼륨 조절
Exec=volume-ctrl
Icon=audio-volume-medium-symbolic
Categories=Settings;
Terminal=false
EOF
}

app_remove_api_volume() {
    rm -f "$_VOLUME_SCRIPT" "$_VOLUME_DESKTOP"
}

app_is_installed_api_volume() {
    [ -x "$_VOLUME_SCRIPT" ]
}
