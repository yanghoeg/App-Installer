#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: 한글 입력기 — Termux native (fcitx5-hangul)
source "${BASH_SOURCE[0]%/*}/../../lib/input_method.sh"

_PKGS_KOREAN_INPUT=(
    fcitx5
    fcitx5-hangul
    fcitx5-configtool
    fcitx5-gtk3
    fcitx5-gtk4
    fcitx5-qt
    libhangul
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

    input_method_select fcitx5 || return 1

    echo "한글 입력기(fcitx5-hangul) 설치 완료"
    echo "XFCE 재시작 후 fcitx5 설정에서 한글(Hangul) 입력기를 추가하세요."
}

app_remove_korean_input() {
    for p in fcitx5-gtk3 fcitx5-gtk4 fcitx5-qt fcitx5-configtool fcitx5-hangul fcitx5 libhangul-static libhangul; do
        if termux_pkg_is_installed "$p"; then termux_pkg_remove "$p" || return 1; fi
    done
    input_method_setup || return 1
    input_method_remove fcitx5
}

app_is_installed_korean_input() {
    termux_pkg_is_installed fcitx5-hangul
}
