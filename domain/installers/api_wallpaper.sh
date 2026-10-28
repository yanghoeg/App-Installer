#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: 배경화면 동기화 — XFCE 배경화면을 Android에 적용

_WALLSYNC_SCRIPT="$PREFIX/bin/wallpaper-sync"
_WALLSYNC_DESKTOP="$PREFIX/share/applications/wallpaper-sync.desktop"

app_install_api_wallpaper() {
    local script_tmp desktop_tmp
    mkdir -p "${_WALLSYNC_SCRIPT%/*}" "${_WALLSYNC_DESKTOP%/*}" || return 1
    script_tmp=$(mktemp "$_WALLSYNC_SCRIPT.tmp.XXXXXX") || return 1
    desktop_tmp=$(mktemp "$_WALLSYNC_DESKTOP.tmp.XXXXXX") || {
        rm -f "$script_tmp"
        return 1
    }
    if ! cat > "$script_tmp" << 'WEOF'; then
#!/data/data/com.termux/files/usr/bin/bash
# XFCE 현재 배경화면을 Android 배경으로 동기화
# 모니터 이름은 X11/VNC 서버에 따라 screen, screen0, VNC-0 등으로 바뀐다.
# 실제 속성 목록에서 현재 작업 공간을 먼저 찾고, 파일이 있는 다른 공간으로 폴백한다.
workspace=$(xprop -root _NET_CURRENT_DESKTOP 2>/dev/null | awk '{print $NF}')
case "$workspace" in ''|*[!0-9]*) workspace=0 ;; esac
if [ "$(xfconf-query -c xfce4-desktop -p /backdrop/single-workspace-mode 2>/dev/null)" = true ]; then
    single_workspace=$(xfconf-query -c xfce4-desktop -p /backdrop/single-workspace-number 2>/dev/null)
    case "$single_workspace" in ''|*[!0-9]*) ;; *) workspace=$single_workspace ;; esac
fi
mapfile -t properties < <(xfconf-query -c xfce4-desktop -l 2>/dev/null)
XFCE_WP=
for pass in current other; do
    for property in "${properties[@]}"; do
        [[ "$property" =~ ^/backdrop/screen[^/]+/monitor[^/]+/workspace[0-9]+/last-image$ ]] || continue
        if [[ "$property" = */workspace"$workspace"/last-image ]]; then
            [ "$pass" = current ] || continue
        else
            [ "$pass" = other ] || continue
        fi
        candidate=$(xfconf-query -c xfce4-desktop -p "$property" 2>/dev/null) || continue
        if [ -n "$candidate" ] && [ -f "$candidate" ]; then
            XFCE_WP=$candidate
            break 2
        fi
    done
done

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
        rm -f "$script_tmp" "$desktop_tmp"
        return 1
    fi
    if ! cat > "$desktop_tmp" << 'EOF'; then
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
        rm -f "$script_tmp" "$desktop_tmp"
        return 1
    fi
    if ! chmod 755 "$script_tmp" || ! chmod 644 "$desktop_tmp"; then
        rm -f "$script_tmp" "$desktop_tmp"
        return 1
    fi
    if ! mv -f "$script_tmp" "$_WALLSYNC_SCRIPT" || ! mv -f "$desktop_tmp" "$_WALLSYNC_DESKTOP"; then
        rm -f "$script_tmp" "$desktop_tmp"
        return 1
    fi
}

app_remove_api_wallpaper() {
    rm -f "$_WALLSYNC_SCRIPT" "$_WALLSYNC_DESKTOP"
}

app_is_installed_api_wallpaper() {
    [ -x "$_WALLSYNC_SCRIPT" ]
}
