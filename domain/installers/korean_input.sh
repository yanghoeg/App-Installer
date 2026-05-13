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
    # tur-repo 필요 (fcitx5 패키지 소스)
    termux_pkg_is_installed tur-repo || termux_pkg_install tur-repo

    # tur-multilib 활성화
    local tur_list="${PREFIX}/etc/apt/sources.list.d/tur.list"
    if [ -f "$tur_list" ]; then
        if ! command grep -q 'tur-multilib' "$tur_list" 2>/dev/null; then
            sed -i '/^deb /s|$| tur-multilib|' "$tur_list" 2>/dev/null || true
            apt update -y 2>/dev/null || true
        fi
    fi

    local total=${#_PKGS_KOREAN_INPUT[@]} i=0
    for p in "${_PKGS_KOREAN_INPUT[@]}"; do
        ((++i))
        if termux_pkg_is_installed "$p"; then
            echo "  (${i}/${total}) ${p} — 이미 설치됨"
        else
            echo "  (${i}/${total}) ${p} 설치 중..."
            termux_pkg_install "$p"
        fi
    done

    # fcitx5 autostart: 시스템 autostart가 있으면 스킵 (중복 인스턴스 방지)
    local system_autostart="${PREFIX}/etc/xdg/autostart/org.fcitx.Fcitx5.desktop"
    if [ ! -f "$system_autostart" ]; then
        mkdir -p "$HOME/.config/autostart"
        local fcitx_desktop="$HOME/.config/autostart/fcitx5.desktop"
        if [ ! -f "$fcitx_desktop" ]; then
            cat > "$fcitx_desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Fcitx5
Exec=fcitx5 -d
Hidden=false
X-GNOME-Autostart-enabled=true
EOF
        fi
    fi

    echo "한글 입력기(fcitx5-hangul) 설치 완료"
    echo "XFCE 재시작 후 fcitx5 설정에서 한글(Hangul) 입력기를 추가하세요."
}

app_remove_korean_input() {
    # 사용자 autostart 제거
    rm -f "$HOME/.config/autostart/fcitx5.desktop"

    for p in fcitx5-configtool fcitx5-hangul fcitx5 libhangul-static libhangul; do
        termux_pkg_is_installed "$p" && termux_pkg_remove "$p"
    done
}

app_is_installed_korean_input() {
    termux_pkg_is_installed fcitx5-hangul
}
