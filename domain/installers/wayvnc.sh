#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: wayvnc — Termux native (x11-repo)
# wlroots 기반 Wayland 컴포지터용 VNC 서버. Anland/KWin과 X11은 지원하지 않는다.
# GUI 항목이 아니라 세션에 붙는 서버라 .desktop 런처는 생성하지 않는다.

_WAYVNC_LAUNCHER="${PREFIX}/bin/wayvnc-start"

_wayvnc_check_compositor() {
    case "${XFCE4_SESSION_COMPOSITOR:-}:${XDG_CURRENT_DESKTOP:-}:${ANLAND:-}" in
        *kwin*|*KDE*|*:1)
            echo "[ERROR] wayvnc는 Anland/KWin을 지원하지 않습니다. wlroots 세션이 필요합니다." >&2
            return 1 ;;
    esac
    if [ -z "${WAYLAND_DISPLAY:-}" ]; then
        echo "[ERROR] wayvnc는 실행 중인 wlroots Wayland 세션이 필요합니다. X11은 지원하지 않습니다." >&2
        return 1
    fi
    # A socket name such as wayland-0 identifies no compositor. Only the known
    # supported external Sway session is accepted; this project's KWin is not.
    local desktop="${XDG_CURRENT_DESKTOP:-}"
    case ":${desktop,,}:" in
        *:sway:*) return 0 ;;
    esac
    echo "[ERROR] 지원되는 Sway 세션을 확인할 수 없습니다. wayvnc는 wlroots 전용입니다." >&2
    return 1
}

_wayvnc_write_launcher() {
    {
    cat << 'LAUNCHEOF'
#!/data/data/com.termux/files/usr/bin/bash
# 실행 중인 wayland 세션에 wayvnc를 붙인다.
#   wayvnc-start [<bind-addr> [<port>]]   기본값 127.0.0.1 5900
# 외부에서 접속하려면 0.0.0.0 으로 바인드할 것 (인증 없이 화면이 노출되므로 주의).

set -uo pipefail
LAUNCHEOF
    declare -f _wayvnc_check_compositor
    cat << 'LAUNCHEOF'
_wayvnc_check_compositor || exit 1
_addr="${1:-127.0.0.1}"
_port="${2:-5900}"

: "${XDG_RUNTIME_DIR:=${PREFIX:-/data/data/com.termux/files/usr}/var/run/user/$(id -u)}"
export XDG_RUNTIME_DIR

export WAYLAND_DISPLAY

echo "wayvnc: WAYLAND_DISPLAY=$WAYLAND_DISPLAY → ${_addr}:${_port}"
exec wayvnc "$_addr" "$_port"
LAUNCHEOF
    } > "$_WAYVNC_LAUNCHER" || return 1
    chmod +x "$_WAYVNC_LAUNCHER"
}

app_install_wayvnc() {
    _wayvnc_check_compositor || return 1
    termux_pkg_enable_repo x11-repo || return 1
    termux_pkg_install wayvnc || return 1
    _wayvnc_write_launcher || return 1

    echo "[wayvnc] 'wayvnc-start' 로 실행합니다 (기본 127.0.0.1:5900)."
    echo "[wayvnc] 외부 Sway 세션 전용 — Anland/KWin 및 X11은 지원하지 않습니다."
}

app_remove_wayvnc() {
    termux_pkg_remove wayvnc || return 1
    rm -f "$_WAYVNC_LAUNCHER"
}

app_is_installed_wayvnc() {
    termux_pkg_is_installed wayvnc
}
