#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: nimf 한글 입력기 — Termux native (deb 직접 설치)
source "${BASH_SOURCE[0]%/*}/../../lib/input_method.sh"
# deb 제공: 흡혈귀왕 @ 미코(미니기기코리아)

_NIMF_DEB_URL="https://github.com/yanghoeg/usix-termux/releases/download/nimf-termux-v1.4.19/nimf_1.4.19_aarch64.deb"
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

# Termux:X11 추가 키 바의 한/영 키 — nimf 기본 단축키 Shift+Space를 실제 키 이벤트로 보낸다.
# Android 키보드의 한글 자판은 Termux:X11이 조합을 흉내만 내서 조합 중 백스페이스가 음절을
# 통째로 지운다. 영문 자판으로 치고 이 키로 nimf를 켜면 X 안에서 조합해 받침부터 지운다.
_NIMF_X11_TOGGLE_KEY="{macro: 'SHIFT SPACE', display: '한/영'}"

# add|remove. Termux:X11 companion 명령이 없으면(Termux:X11 미사용) 할 일이 없다.
# termux-x11-preference는 stdin이 tty가 아니면 EOF까지 읽고 key:value 인자의 값을 콜론마다
# 자르므로, 읽을 때는 </dev/null, 쓸 때는 stdin의 "key"="value" 줄을 쓴다.
_nimf_x11_toggle_key() {
    local config new
    command -v termux-x11-preference >/dev/null 2>&1 || return 0
    config=$(timeout 20 termux-x11-preference list < /dev/null 2>/dev/null |
        sed -n 's/^"extra_keys_config"="\(.*\)"$/\1/p')
    [ -n "$config" ] || return 1
    if [ "$1" = add ]; then
        case "$config" in
            *"$_NIMF_X11_TOGGLE_KEY"*) return 0 ;;
            *']]') new="${config%]]},$_NIMF_X11_TOGGLE_KEY]]" ;;
            *) return 1 ;;
        esac
    else
        case "$config" in *",$_NIMF_X11_TOGGLE_KEY"*) ;; *) return 0 ;; esac
        new="${config//",$_NIMF_X11_TOGGLE_KEY"/}"
    fi
    case "$new" in *'"'*|*=*) return 1 ;; esac
    printf '"extra_keys_config"="%s"\n' "$new" | timeout 20 termux-x11-preference >/dev/null 2>&1
}

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

    _nimf_x11_toggle_key add ||
        echo "[WARN] Termux:X11 추가 키 바에 한/영 키를 넣지 못했습니다. 설정의 extra keys config에 직접 추가하세요: $_NIMF_X11_TOGGLE_KEY" >&2

    echo "nimf 한글 입력기 설치 완료"
    echo "XFCE 재시작 후 nimf-settings에서 한글 입력기를 설정하세요."
    echo "Android 키보드는 영문 자판으로 두고 한/영 키(Shift+Space)로 한글을 켜세요."
}

app_remove_nimf() {
    dpkg -r nimf || return 1
    _nimf_x11_toggle_key remove ||
        echo "[WARN] Termux:X11 추가 키 바의 한/영 키를 지우지 못했습니다." >&2
    input_method_setup || return 1
    input_method_remove nimf
}

app_is_installed_nimf() {
    command -v nimf &>/dev/null
}
