#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: nimf 한글 입력기 — Termux native (deb 직접 설치)
source "${BASH_SOURCE[0]%/*}/../../lib/input_method.sh"
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

    input_method_select nimf || return 1

    echo "nimf 한글 입력기 설치 완료"
    echo "XFCE 재시작 후 nimf-settings에서 한글 입력기를 설정하세요."
}

app_remove_nimf() {
    dpkg -r nimf || return 1
    input_method_setup || return 1
    input_method_remove nimf
}

app_is_installed_nimf() {
    command -v nimf &>/dev/null
}
