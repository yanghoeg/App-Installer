#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: wayvnc — Termux native (x11-repo)
# wlroots 기반 Wayland 컴포지터용 VNC 서버. 이 프로젝트의 wayland 어댑터는
# labwc(wlroots) 를 쓰므로 그대로 붙는다. X11 세션에서는 동작하지 않는다.
# GUI 항목이 아니라 세션에 붙는 서버라 .desktop 런처는 생성하지 않는다.

_WAYVNC_LAUNCHER="${PREFIX}/bin/wayvnc-start"

_wayvnc_write_launcher() {
    cat > "$_WAYVNC_LAUNCHER" << 'LAUNCHEOF'
#!/data/data/com.termux/files/usr/bin/bash
# 실행 중인 wayland 세션에 wayvnc를 붙인다.
#   wayvnc-start [<bind-addr> [<port>]]   기본값 127.0.0.1 5900
# 외부에서 접속하려면 0.0.0.0 으로 바인드할 것 (인증 없이 화면이 노출되므로 주의).

set -uo pipefail
_addr="${1:-127.0.0.1}"
_port="${2:-5900}"

: "${XDG_RUNTIME_DIR:=${PREFIX:-/data/data/com.termux/files/usr}/var/run/user/$(id -u)}"
export XDG_RUNTIME_DIR

if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    for _sock in "$XDG_RUNTIME_DIR"/wayland-*; do
        case "$_sock" in
            *.lock|*'wayland-*') continue ;;
        esac
        [ -S "$_sock" ] || continue
        WAYLAND_DISPLAY="$(basename "$_sock")"
        break
    done
fi

if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    echo "[ERROR] wayland 소켓을 찾을 수 없습니다: $XDG_RUNTIME_DIR" >&2
    echo "        wayland 세션(startXFCE)이 실행 중인지 확인하세요." >&2
    exit 1
fi
export WAYLAND_DISPLAY

echo "wayvnc: WAYLAND_DISPLAY=$WAYLAND_DISPLAY → ${_addr}:${_port}"
exec wayvnc "$_addr" "$_port"
LAUNCHEOF
    chmod +x "$_WAYVNC_LAUNCHER"
}

app_install_wayvnc() {
    termux_pkg_enable_repo x11-repo || return 1
    termux_pkg_install wayvnc || return 1
    _wayvnc_write_launcher || return 1

    echo "[wayvnc] 'wayvnc-start' 로 실행합니다 (기본 127.0.0.1:5900)."
    echo "[wayvnc] wayland 세션 전용 — --display wayland 로 설치한 경우에만 동작합니다."
}

app_remove_wayvnc() {
    termux_pkg_remove wayvnc
    rm -f "$_WAYVNC_LAUNCHER"
}

app_is_installed_wayvnc() {
    termux_pkg_is_installed wayvnc
}
