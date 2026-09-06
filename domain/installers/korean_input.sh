#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: 한글 입력기 — Termux native (fcitx5-hangul)

_PKGS_KOREAN_INPUT=(
    fcitx5
    fcitx5-hangul
    fcitx5-configtool
    libhangul
    libhangul-static
)

app_install_korean_input() {
    # x11-repo 필요 (fcitx5 패키지 소스)
    termux_pkg_enable_repo x11-repo || return 1

    local total=${#_PKGS_KOREAN_INPUT[@]} i=0
    for p in "${_PKGS_KOREAN_INPUT[@]}"; do
        ((++i))
        if termux_pkg_is_installed "$p"; then
            echo "  (${i}/${total}) ${p} — 이미 설치됨"
        else
            echo "  (${i}/${total}) ${p} 설치 중..."
            termux_pkg_install "$p" || return 1
        fi
    done

    _fcitx5_setup_env
    _fcitx5_setup_autostart

    echo "한글 입력기(fcitx5-hangul) 설치 완료"
    echo "XFCE 재시작 후 fcitx5 설정에서 한글(Hangul) 입력기를 추가하세요."
}

_fcitx5_setup_env() {
    local rc
    for rc in "${PREFIX}/etc/bash.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] || continue
        # nimf → fcitx5 전환
        sed -i 's/GTK_IM_MODULE=nimf/GTK_IM_MODULE=fcitx5/g' "$rc" 2>/dev/null
        sed -i 's/QT_IM_MODULE=nimf/QT_IM_MODULE=fcitx5/g' "$rc" 2>/dev/null
        sed -i 's/@im=nimf/@im=fcitx5/g' "$rc" 2>/dev/null
        # nimf 블록 제거
        sed -i '/# termux-xfce-nimf/,/# end-termux-xfce-nimf/d' "$rc" 2>/dev/null || true
    done
}

_fcitx5_setup_autostart() {
    # nimf autostart 제거
    rm -f "$HOME/.config/autostart/nimf.desktop"
    # fcitx5 사용자 오버라이드(Hidden=true) 제거 → 시스템 autostart 복원
    rm -f "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop"

    # 시스템 autostart가 없는 경우 사용자 autostart 생성
    local system_autostart="${PREFIX}/etc/xdg/autostart/org.fcitx.Fcitx5.desktop"
    if [ ! -f "$system_autostart" ]; then
        mkdir -p "$HOME/.config/autostart"
        local fcitx_desktop="$HOME/.config/autostart/fcitx5.desktop"
        [ -f "$fcitx_desktop" ] || cat > "$fcitx_desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Fcitx5
Exec=fcitx5 -d
Hidden=false
X-GNOME-Autostart-enabled=true
EOF
    fi
}

app_remove_korean_input() {
    # 사용자 autostart 제거
    rm -f "$HOME/.config/autostart/fcitx5.desktop"

    for p in fcitx5-configtool fcitx5-hangul fcitx5 libhangul-static libhangul; do
        termux_pkg_is_installed "$p" && termux_pkg_remove "$p"
    done
    return 0
}

app_is_installed_korean_input() {
    termux_pkg_is_installed fcitx5-hangul
}
