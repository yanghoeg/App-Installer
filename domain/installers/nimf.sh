#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: nimf 한글 입력기 — Termux native (deb 직접 설치)
# deb 제공: 흡혈귀왕 @ 미코(미니기기코리아)

_NIMF_DEB_URL="https://github.com/yanghoeg/Termux_XFCE/releases/download/nimf-termux-v1.4.19/nimf_1.4.19_aarch64.deb"
_NIMF_DEB_SHA256="42e6f5a27ec99bc26b2492e08181d433caf26a3832867eef664bb935144c7fbe"

_NIMF_DEPS=(
    glib
    libhangul
    libxkbcommon
    libx11
    libwayland
    gtk2
    gtk3
    gtk4
    qt5-qtbase
    qt6-qtbase
    libxklavier
    libayatana-appindicator
    dbus
)

app_install_nimf() {
    termux_pkg_enable_repo x11-repo || return 1
    local total=${#_NIMF_DEPS[@]} i=0
    for p in "${_NIMF_DEPS[@]}"; do
        ((++i))
        if termux_pkg_is_installed "$p"; then
            echo "  (${i}/${total}) ${p} — 이미 설치됨"
        else
            echo "  (${i}/${total}) ${p} 설치 중..."
            termux_pkg_install "$p" || return 1
        fi
    done

    local deb_file="${TMPDIR:-/tmp}/nimf_1.4.19_aarch64.deb"
    echo "nimf deb 다운로드 중..."
    fetch_verified "$_NIMF_DEB_URL" "$deb_file" "$_NIMF_DEB_SHA256" || {
        echo "[ERROR] nimf deb 다운로드/검증 실패" >&2
        return 1
    }

    echo "nimf 설치 중..."
    if ! dpkg -i --force-overwrite "$deb_file"; then
        rm -f "$deb_file"
        return 1
    fi
    rm -f "$deb_file"

    glib-compile-schemas "${PREFIX}/share/glib-2.0/schemas/" 2>/dev/null || true

    _nimf_setup_env
    _nimf_setup_autostart

    echo "nimf 한글 입력기 설치 완료"
    echo "XFCE 재시작 후 nimf-settings에서 한글 입력기를 설정하세요."
}

_nimf_setup_env() {
    local rc
    for rc in "${PREFIX}/etc/bash.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] || continue
        # fcitx5 → nimf 전환
        sed -i 's/GTK_IM_MODULE=fcitx5\?/GTK_IM_MODULE=nimf/g' "$rc" 2>/dev/null
        sed -i 's/QT_IM_MODULE=fcitx5\?/QT_IM_MODULE=nimf/g' "$rc" 2>/dev/null
        sed -i 's/@im=fcitx5\?/@im=nimf/g' "$rc" 2>/dev/null
        # 위 치환이 안 됐으면 (fcitx5 블록 자체가 없는 경우) 새로 추가
        command grep -q 'GTK_IM_MODULE=nimf' "$rc" 2>/dev/null && continue
        cat >> "$rc" << 'ENVBLOCK'

# termux-xfce-nimf
export GTK_IM_MODULE=nimf
export QT_IM_MODULE=nimf
export XMODIFIERS="@im=nimf"
# end-termux-xfce-nimf
ENVBLOCK
    done
}

_nimf_setup_autostart() {
    mkdir -p "$HOME/.config/autostart"

    # nimf autostart 생성
    local desktop="$HOME/.config/autostart/nimf.desktop"
    [ -f "$desktop" ] || cat > "$desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Nimf
Exec=bash -c "pgrep -x nimf >/dev/null 2>&1 || exec nimf"
Hidden=false
X-GNOME-Autostart-enabled=true
EOF

    # fcitx5 autostart 비활성화
    local fcitx_sys="${PREFIX}/etc/xdg/autostart/org.fcitx.Fcitx5.desktop"
    if [ -f "$fcitx_sys" ]; then
        cat > "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Fcitx5
Exec=fcitx5 -d
Hidden=true
X-GNOME-Autostart-enabled=false
EOF
    fi
    rm -f "$HOME/.config/autostart/fcitx5.desktop"
}

app_remove_nimf() {
    rm -f "$HOME/.config/autostart/nimf.desktop"
    rm -f "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop"

    local rc
    for rc in "${PREFIX}/etc/bash.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] || continue
        sed -i '/# termux-xfce-nimf/,/# end-termux-xfce-nimf/d' "$rc" 2>/dev/null || true
    done

    dpkg -r nimf 2>/dev/null || true
}

app_is_installed_nimf() {
    command -v nimf &>/dev/null
}
