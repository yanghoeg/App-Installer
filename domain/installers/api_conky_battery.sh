#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Conky 배터리 위젯 — termux-battery-status 연동

_CONKY_BATTERY_SCRIPT="$HOME/.local/bin/conky-battery"
_CONKY_BATTERY_RC="$HOME/.config/conky/battery.conf"

app_install_api_conky_battery() {
    mkdir -p "$(dirname "$_CONKY_BATTERY_SCRIPT")" "$(dirname "$_CONKY_BATTERY_RC")"

    cat > "$_CONKY_BATTERY_SCRIPT" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
termux-battery-status 2>/dev/null | jq -r \
    '"🔋 " + (.percentage|tostring) + "% · " + (.temperature|tostring) + "°C · " + .status'
EOF
    chmod +x "$_CONKY_BATTERY_SCRIPT"

    cat > "$_CONKY_BATTERY_RC" << 'EOF'
conky.config = {
    alignment = 'top_right',
    gap_x = 15, gap_y = 60,
    update_interval = 30,
    use_xft = true,
    font = 'MesloLGS Nerd Font Mono:size=11',
    own_window = true,
    own_window_type = 'override',
    own_window_transparent = true,
    double_buffer = true,
    draw_shades = false,
    default_color = 'white',
    minimum_width = 220,
}
conky.text = [[${execpi 30 conky-battery}]]
EOF
    echo "설치 완료. 실행: conky -c ~/.config/conky/battery.conf &"
}

app_remove_api_conky_battery() {
    rm -f "$_CONKY_BATTERY_SCRIPT" "$_CONKY_BATTERY_RC"
}

app_is_installed_api_conky_battery() {
    [ -x "$_CONKY_BATTERY_SCRIPT" ] && [ -f "$_CONKY_BATTERY_RC" ]
}
