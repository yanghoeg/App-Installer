#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# lib/wine_backend.sh — Wine 백엔드 선택 (box64 | hangover)
# =============================================================================
# 두 백엔드가 동시에 설치될 수 있다. 실제 바이너리는 서로 다른 경로에 놓이고,
# PATH 상의 `wine`은 활성 백엔드로 위임하는 디스패처다.
#
#   $PREFIX/bin/wine            디스패처 (활성 백엔드로 exec)
#   $PREFIX/bin/wine-box64      Box64 + Wine-Staging 래퍼 (proot 또는 glibc-runner)
#   $PREFIX/bin/wine-hangover   Hangover(FEX/ARM64EC) 래퍼 → hangover-wine
#   $PREFIX/bin/wine-backend    사용자 CLI (현재값 출력 / 전환)
#
# 활성 백엔드는 $HOME/.config/termux-xfce/wine-backend 한 줄에 저장한다.
# (termux-xfce/config 는 install.sh 가 통째로 덮어쓰므로 별도 파일을 쓴다)

[ -n "${_WINE_BACKEND_SH:-}" ] && return 0
_WINE_BACKEND_SH=1

_WINE_BACKEND_CONF="${HOME}/.config/termux-xfce/wine-backend"
_WINE_BOX64_BIN="${PREFIX}/bin/wine-box64"
_WINE_HANGOVER_BIN="${PREFIX}/bin/wine-hangover"
_WINE_DISPATCHER="${PREFIX}/bin/wine"
_WINE_BACKEND_CLI="${PREFIX}/bin/wine-backend"

# -----------------------------------------------------------------------------
# 조회
# -----------------------------------------------------------------------------

# 활성 백엔드 이름 출력 — hangover | box64
# 설정 파일이 없거나 값이 잘못됐으면 설치된 것 중 hangover를 우선한다.
wine_backend() {
    local b=""
    [ -r "$_WINE_BACKEND_CONF" ] && read -r b < "$_WINE_BACKEND_CONF" 2>/dev/null

    case "$b" in
        hangover|box64)
            # 설정값이 가리키는 백엔드가 실제로 있으면 그대로 사용
            [ -x "${PREFIX}/bin/wine-${b}" ] && { printf '%s' "$b"; return 0; }
            ;;
    esac

    if [ -x "$_WINE_HANGOVER_BIN" ]; then
        printf '%s' "hangover"
    else
        printf '%s' "box64"
    fi
}

# 백엔드가 하나라도 설치돼 있는가
wine_backend_available() {
    [ -x "$_WINE_BOX64_BIN" ] || [ -x "$_WINE_HANGOVER_BIN" ]
}

# 활성 백엔드의 WINEPREFIX
# 주의: box64 + proot 조합에서는 이 값이 "컨테이너 내부" 경로다.
#       Termux 측 파일 경로로 그대로 쓰면 안 된다 — wine_exec_shell을 쓸 것.
wine_prefix() {
    case "$(wine_backend)" in
        hangover) printf '%s' "${HOME}/.wine-hangover" ;;
        *)        printf '%s' "${HOME}/.wine" ;;
    esac
}

# -----------------------------------------------------------------------------
# 설정
# -----------------------------------------------------------------------------

# 활성 백엔드 기록. $1 = hangover | box64
wine_backend_set() {
    local b="${1:-}"
    case "$b" in
        hangover|box64) ;;
        *) echo "[ERROR] 알 수 없는 Wine 백엔드: ${b} (hangover|box64)" >&2; return 1 ;;
    esac
    mkdir -p "$(dirname "$_WINE_BACKEND_CONF")" || return 1
    printf '%s\n' "$b" > "$_WINE_BACKEND_CONF"
}

# 설정 파일이 아직 없을 때만 기록 (설치기가 사용자의 선택을 덮어쓰지 않도록)
wine_backend_set_default() {
    [ -r "$_WINE_BACKEND_CONF" ] && return 0
    wine_backend_set "$1"
}

# -----------------------------------------------------------------------------
# 실행
# -----------------------------------------------------------------------------

# 활성 백엔드의 문맥에서 셸 조각을 실행하고 WINEPREFIX를 주입한다.
# 조각 안에서는 $WINEPREFIX 를 쓰면 되고, box64+proot면 컨테이너 안에서,
# 그 외(hangover / box64 native)는 Termux 안에서 실행된다.
# 조각 안의 `wine` 호출은 각 문맥의 wine(컨테이너 wine / PATH 디스패처)으로 간다.
wine_exec_shell() {
    local snippet="$1"

    if [ "$(wine_backend)" = "box64" ] && has_proot_distro; then
        # proot_exec_wine: DISPLAY + Mesa/Zink env를 컨테이너로 넘긴다
        proot_exec_wine bash -c 'export WINEPREFIX="$HOME/.wine"
'"$snippet"
    else
        DISPLAY="${DISPLAY:-:0.0}" WINEPREFIX="$(wine_prefix)" bash -c "$snippet"
    fi
}

# -----------------------------------------------------------------------------
# 래퍼/디스패처 생성
# -----------------------------------------------------------------------------

# 백엔드 래퍼가 공유하는 환경변수 블록 (Mesa/Vulkan/Wine 공통)
# box64 전용(BOX64_*)·DXVK 설정은 호출하는 쪽에서 덧붙인다.
wine_emit_env_block() {
    cat << 'ENVEOF'
export DISPLAY="${DISPLAY:-:0.0}"
# Mesa / Vulkan
export MESA_LOADER_DRIVER_OVERRIDE="${MESA_LOADER_DRIVER_OVERRIDE:-zink}"
export TU_DEBUG=noconform
export ZINK_DESCRIPTORS=lazy
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE="${MESA_GL_VERSION_OVERRIDE:-4.6COMPAT}"
export MESA_GLSL_VERSION_OVERRIDE="${MESA_GLSL_VERSION_OVERRIDE:-460}"
export MESA_GLES_VERSION_OVERRIDE="${MESA_GLES_VERSION_OVERRIDE:-3.2}"
# Wine
export WINEESYNC=1
export WINEDEBUG="${WINEDEBUG:--all}"
ENVEOF
}

# $PREFIX/bin/wine — 활성 백엔드로 위임하는 디스패처
wine_write_dispatcher() {
    mkdir -p "${PREFIX}/bin" || return 1

    # 마이그레이션: 백엔드 분리 이전 설치는 $PREFIX/bin/wine 자체가 box64 래퍼였다.
    # 디스패처로 덮어쓰기 전에 wine-box64로 옮겨 보존한다.
    # (wine-staging 문자열로 우리 래퍼임을 확인 — 다른 패키지의 wine은 건드리지 않는다)
    if [ -f "$_WINE_DISPATCHER" ] && [ ! -e "$_WINE_BOX64_BIN" ] \
       && grep -q 'wine-staging' "$_WINE_DISPATCHER" 2>/dev/null; then
        mv "$_WINE_DISPATCHER" "$_WINE_BOX64_BIN" && chmod +x "$_WINE_BOX64_BIN"
    fi

    cat > "$_WINE_DISPATCHER" << 'DISPEOF'
#!/data/data/com.termux/files/usr/bin/bash
# termux-xfce-wine-dispatcher
# Wine 디스패처 — 활성 백엔드로 위임한다.
# 전환: wine-backend hangover  /  wine-backend box64

_conf="$HOME/.config/termux-xfce/wine-backend"
_b=""
[ -r "$_conf" ] && read -r _b < "$_conf" 2>/dev/null

case "$_b" in
    hangover|box64) ;;
    *) _b="" ;;
esac

# 설정된 백엔드가 없거나 실제로 설치돼 있지 않으면 남은 쪽으로 폴백
if [ -z "$_b" ] || [ ! -x "$PREFIX/bin/wine-$_b" ]; then
    if [ -x "$PREFIX/bin/wine-hangover" ]; then
        _b=hangover
    elif [ -x "$PREFIX/bin/wine-box64" ]; then
        _b=box64
    else
        echo "[ERROR] Wine 백엔드가 설치되어 있지 않습니다." >&2
        echo "        App Installer에서 'Wine (Hangover)' 또는 'Wine (Box64+Staging)'을 설치하세요." >&2
        exit 1
    fi
fi

exec "$PREFIX/bin/wine-$_b" "$@"
DISPEOF
    chmod +x "$_WINE_DISPATCHER"
}

# $PREFIX/bin/wine-backend — 사용자용 전환 CLI
wine_write_backend_cli() {
    mkdir -p "${PREFIX}/bin" || return 1
    cat > "$_WINE_BACKEND_CLI" << 'CLIEOF'
#!/data/data/com.termux/files/usr/bin/bash
# wine-backend             — 현재 백엔드와 설치 상태 출력
# wine-backend hangover    — Hangover(FEX/ARM64EC)로 전환
# wine-backend box64       — Box64 + Wine-Staging으로 전환

set -uo pipefail
_conf="$HOME/.config/termux-xfce/wine-backend"

_installed() { [ -x "$PREFIX/bin/wine-$1" ] && echo "설치됨" || echo "미설치"; }

_current() {
    local b=""
    [ -r "$_conf" ] && read -r b < "$_conf" 2>/dev/null
    case "$b" in
        hangover|box64) [ -x "$PREFIX/bin/wine-$b" ] && { echo "$b"; return; } ;;
    esac
    [ -x "$PREFIX/bin/wine-hangover" ] && echo hangover || echo box64
}

case "${1:-}" in
    "")
        echo "활성 백엔드 : $(_current)"
        echo "  hangover  : $(_installed hangover)   FEX/ARM64EC, Termux native, WINEPREFIX=\$HOME/.wine-hangover"
        echo "  box64     : $(_installed box64)   Box64 + Wine-Staging,      WINEPREFIX=\$HOME/.wine"
        ;;
    hangover|box64)
        if [ ! -x "$PREFIX/bin/wine-$1" ]; then
            echo "[ERROR] '$1' 백엔드가 설치되어 있지 않습니다." >&2
            exit 1
        fi
        mkdir -p "$(dirname "$_conf")"
        printf '%s\n' "$1" > "$_conf"
        echo "활성 Wine 백엔드를 '$1'로 전환했습니다."
        ;;
    -h|--help|help)
        sed -n '2,4p' "$0" | sed 's/^# //'
        ;;
    *)
        echo "[ERROR] 알 수 없는 인자: $1 (hangover|box64)" >&2
        exit 1
        ;;
esac
CLIEOF
    chmod +x "$_WINE_BACKEND_CLI"
}

# 백엔드 설치기가 끝날 때 공통으로 부르는 배선 함수
wine_wire_frontend() {
    wine_write_dispatcher || return 1
    wine_write_backend_cli || return 1
}
