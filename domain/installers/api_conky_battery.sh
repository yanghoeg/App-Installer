#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: 배터리 위젯 — termux-battery-status + xfce4-genmon-plugin

_BATTERY_SCRIPT="$HOME/.local/bin/battery-genmon"
_BATTERY_POPUP="$PREFIX/bin/battery-info"
_BATTERY_DESKTOP="$PREFIX/share/applications/battery-info.desktop"

app_install_api_conky_battery() {
    termux_pkg_install xfce4-genmon-plugin

    mkdir -p "$(dirname "$_BATTERY_SCRIPT")"

    # genmon용 스크립트 (패널 위젯 — 30초마다 자동 갱신)
    cat > "$_BATTERY_SCRIPT" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
json=$(termux-battery-status 2>/dev/null) || { echo "<txt>--</txt>"; exit 0; }
pct=$(echo "$json" | jq -r '.percentage // "?"')
temp=$(echo "$json" | jq -r '.temperature // "?"')
status=$(echo "$json" | jq -r '.status // "?"')
case "$status" in
    CHARGING)    label="⚡${pct}%" ;;
    FULL)        label="🔌${pct}%" ;;
    *)           label="🔋${pct}%" ;;
esac
echo "<txt>${label}</txt>"
echo "<tool>온도: ${temp}°C | 상태: ${status}</tool>"
echo "<click>${PREFIX}/bin/battery-info</click>"
EOF
    chmod +x "$_BATTERY_SCRIPT"

    # 수동 확인용 yad 팝업
    cat > "$_BATTERY_POPUP" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
json=$(termux-battery-status 2>/dev/null) || { echo "termux-api 오류"; exit 1; }
pct=$(echo "$json" | jq -r '.percentage // "?"')
temp=$(echo "$json" | jq -r '.temperature // "?"')
status=$(echo "$json" | jq -r '.status // "?"')
health=$(echo "$json" | jq -r '.health // "?"')
volt=$(echo "$json" | jq -r '(.voltage // 0) / 1000.0')
yad --info --title="배터리 정보" --width=300 --center \
    --text="잔량: ${pct}%\n온도: ${temp}°C\n상태: ${status}\n건강: ${health}\n전압: ${volt}V" \
    2>/dev/null || \
zenity --info --title="배터리 정보" --width=300 \
    --text="잔량: ${pct}%\n온도: ${temp}°C\n상태: ${status}\n건강: ${health}\n전압: ${volt}V" \
    2>/dev/null
EOF
    chmod +x "$_BATTERY_POPUP"

    mkdir -p "$(dirname "$_BATTERY_DESKTOP")"
    cat > "$_BATTERY_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=배터리 정보
Exec=battery-info
Icon=battery-good-symbolic
Categories=System;
Terminal=false
EOF

    echo "설치 완료."
    echo "  패널 위젯: 패널 → 항목 추가 → Generic Monitor → 명령: $HOME/.local/bin/battery-genmon"
    echo "  수동 확인: battery-info"
}

app_remove_api_conky_battery() {
    rm -f "$_BATTERY_SCRIPT" "$_BATTERY_POPUP" "$_BATTERY_DESKTOP"
}

app_is_installed_api_conky_battery() {
    [ -x "$_BATTERY_SCRIPT" ]
}
