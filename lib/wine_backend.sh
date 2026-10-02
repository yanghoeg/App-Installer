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
_WINE_BOX64_CONTEXT="${HOME}/.config/termux-xfce/wine-box64-context"
_WINE_APP_STATE="${HOME}/.config/termux-xfce/wine-apps"
_WINE_BACKEND_LIB="$(cd "${BASH_SOURCE[0]%/*}" && pwd)/wine_backend.sh"

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

# Context records contain data, never shell code:
# backend|native/proot|distro|user|rootfs-base (empty base means the default).
_wine_context_valid() {
    local backend mode distro user base extra
    IFS='|' read -r backend mode distro user base extra <<< "$1"
    [ -z "${extra:-}" ] && [[ "$1" != *$'\n'* ]] || return 1
    case "$backend:$mode" in
        box64:native|hangover:native) [ "$1" = "$backend|native|||" ] ;;
        box64:proot)
            case "$distro" in ubuntu|archlinux) ;; *) return 1 ;; esac
            [[ "$user" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]] || return 1
            [ "$1" = "box64|proot|$distro|$user|$base" ] || return 1
            [ -z "$base" ] || [[ "$base" = /* ]] ;;
        *) return 1 ;;
    esac
}

_wine_context_write() {
    local file="$1" context="$2" stage
    _wine_context_valid "$context" || return 1
    mkdir -p "${file%/*}" || return 1
    stage=$(mktemp "${file}.XXXXXX") || return 1
    if ! printf '%s\n' "$context" > "$stage" || ! mv -f "$stage" "$file"; then
        rm -f "$stage"
        return 1
    fi
}

wine_backend_record_context() {
    local context="box64|${1}|${2:-}|${3:-}|${4:-}"
    _wine_context_write "$_WINE_BOX64_CONTEXT" "$context"
}

wine_backend_context() {
    local backend="${1:-$(wine_backend)}" context=''
    if [ "$backend" = hangover ]; then
        printf '%s\n' 'hangover|native|||'
        return 0
    fi
    [ "$backend" = box64 ] || return 1
    if [ -f "$_WINE_BOX64_CONTEXT" ]; then
        IFS= read -r context < "$_WINE_BOX64_CONTEXT" || [ -n "$context" ] || return 1
    elif [ -r "$_WINE_BOX64_BIN" ]; then
        # New wrappers retain their target even if the context file is missing.
        context=$(sed -n 's/^# wine-context: //p' "$_WINE_BOX64_BIN") || return 1
        if [ -z "$context" ] && grep -Eq 'exec prun|proot-distro login' "$_WINE_BOX64_BIN"; then
            context="box64|proot|${PROOT_DISTRO:-}|${PROOT_USER:-}|${PROOT_ROOTFS_BASE:-}"
        fi
    fi
    # A native wrapper stays native when a container is added later. Unknown
    # legacy wrappers also stay on the host; container presence is not ownership.
    context="${context:-box64|native|||}"
    _wine_context_valid "$context" && [[ "$context" = box64\|* ]] || return 1
    printf '%s\n' "$context"
}

# Scope the saved target to this operation. Adapter proot_exec is generic and
# reads these variables; a generated app launcher loads that generic adapter.
wine_exec_shell() (
    local snippet="$1" context backend mode distro user base
    if [ "$#" -gt 1 ]; then context="$2"; shift 2
    else context=$(wine_backend_context) || return 1; shift; fi
    _wine_context_valid "$context" || return 1
    IFS='|' read -r backend mode distro user base <<< "$context"
    if [ "$mode" = proot ]; then
        export PROOT_DISTRO="$distro" PROOT_USER="$user"
        if [ -n "$base" ]; then export PROOT_ROOTFS_BASE="$base"; else unset PROOT_ROOTFS_BASE; fi
        [ -d "$(_proot_rootfs)" ] || { echo '[ERROR] 저장된 Wine 컨테이너가 없습니다.' >&2; return 1; }
        proot_exec_wine bash -c '
            export WINEPREFIX="$HOME/.wine" WINEESYNC=1 WINEDEBUG="${WINEDEBUG:--all}"
            wine() { /opt/wine-staging/bin/wine "$@"; }
        '"$snippet" wine-context "$@"
    else
        local runner="${WINE_CONTEXT_RUNNER:-${PREFIX}/bin/wine-${backend}}"
        DISPLAY="${DISPLAY:-:0.0}" WINEPREFIX="$(wine_prefix_for_backend "$backend")" \
            bash -c 'runner=$1; shift; wine() { "$runner" "$@"; }
'"$snippet" wine-context "$runner" "$@"
    fi
)

wine_prefix_for_backend() {
    case "$1" in
        hangover) printf '%s' "$HOME/.wine-hangover" ;;
        box64) printf '%s' "$HOME/.wine" ;;
        *) return 1 ;;
    esac
}

_wine_app_relpath() {
    case "$1" in
        sevenzip) printf '%s' '7-Zip/7zFM.exe' ;;
        notepadpp) printf '%s' 'Program Files/Notepad++/notepad++.exe' ;;
        sumatrapdf) printf '%s' 'Program Files/SumatraPDF/SumatraPDF.exe' ;;
        winmerge) printf '%s' 'Program Files/WinMerge/WinMergeU.exe' ;;
        *) return 1 ;;
    esac
}

_wine_app_file() (
    local context="$1" id="$2" backend mode distro user base rootfs userhome rel
    _wine_context_valid "$context" || return 1
    rel=$(_wine_app_relpath "$id") || return 1
    IFS='|' read -r backend mode distro user base <<< "$context"
    if [ "$mode" = native ]; then
        printf '%s/drive_c/%s\n' "$(wine_prefix_for_backend "$backend")" "$rel"
    else
        export PROOT_DISTRO="$distro" PROOT_USER="$user"
        if [ -n "$base" ]; then export PROOT_ROOTFS_BASE="$base"; else unset PROOT_ROOTFS_BASE; fi
        rootfs=$(_proot_rootfs) || return 1
        [ -d "$rootfs" ] || return 1
        userhome=$(awk -F: -v user="$user" '$1 == user {print $6; exit}' "$rootfs/etc/passwd" 2>/dev/null) || userhome=''
        if [ -z "$userhome" ]; then
            if [ "$user" = root ]; then userhome=/root; else userhome="/home/$user"; fi
        fi
        [[ "$userhome" = /* ]] && [[ "$userhome" != *'/../'* ]] || return 1
        printf '%s%s/.wine/drive_c/%s\n' "$rootfs" "$userhome" "$rel"
    fi
)

# Old desktop-only installs have no ownership record. Inspect actual executables
# in both native prefixes and available containers before migrating their entry.
wine_app_context() {
    local id="$1" context file backend distro user rootfs base
    _wine_app_relpath "$id" >/dev/null || return 1
    file="$_WINE_APP_STATE/$id.context"
    if [ -f "$file" ]; then
        IFS= read -r context < "$file" || [ -n "$context" ] || return 1
        _wine_context_valid "$context" || return 1
        printf '%s\n' "$context"
        return 0
    fi
    for backend in "$(wine_backend)" hangover box64; do
        context=$(wine_backend_context "$backend") || continue
        file=$(_wine_app_file "$context" "$id") || continue
        if [ -f "$file" ]; then printf '%s\n' "$context"; return 0; fi
    done
    context='box64|native|||'
    file=$(_wine_app_file "$context" "$id") || return 1
    if [ -f "$file" ]; then printf '%s\n' "$context"; return 0; fi
    base="${PROOT_ROOTFS_BASE:-$PREFIX/var/lib/proot-distro}"
    for distro in ubuntu archlinux; do
        for rootfs in "$base/containers/$distro/rootfs" "$base/installed-rootfs/$distro"; do
            [ -d "$rootfs" ] || continue
            for file in "$rootfs"/home/* "$rootfs/root"; do
                [ -d "$file" ] || continue
                user="${file##*/}"
                context="box64|proot|$distro|$user|${PROOT_ROOTFS_BASE:-}"
                _wine_context_valid "$context" || continue
                file=$(_wine_app_file "$context" "$id") || continue
                if [ -f "$file" ]; then printf '%s\n' "$context"; return 0; fi
            done
        done
    done
    return 1
}

wine_app_write_launcher() {
    local id="$1" launcher="${PREFIX}/bin/wine-app-${1}" stage desktop
    _wine_app_relpath "$id" >/dev/null || return 1
    stage=$(mktemp "${launcher}.XXXXXX") || return 1
    {
        printf '#!%s/bin/bash\n' "$PREFIX"
        printf 'source %q || exit 1\n' "${_WINE_BACKEND_LIB%/*}/proot_path.sh"
        printf 'source %q || exit 1\n' "${_WINE_BACKEND_LIB%/*}/../adapters/output/pkg_proot_base.sh"
        printf 'source %q || exit 1\n' "$_WINE_BACKEND_LIB"
        printf 'wine_app_launch %q "$@"\n' "$id"
    } > "$stage" || { rm -f "$stage"; return 1; }
    chmod +x "$stage" && mv -f "$stage" "$launcher" || { rm -f "$stage"; return 1; }
    # Field codes now remain separate argv, outside any bash -c string.
    for desktop in "$PREFIX/share/applications/$id.desktop" "$HOME/Desktop/$id.desktop"; do
        [ -f "$desktop" ] || continue
        sed -i "s|^Exec=.*|Exec=wine-app-$id %f|" "$desktop" || return 1
    done
}

wine_app_record() {
    local id="$1" context="${2:-}" backend mode distro user base stage runner
    _wine_app_relpath "$id" >/dev/null || return 1
    [ -n "$context" ] || context=$(wine_backend_context) || return 1
    _wine_context_valid "$context" || return 1
    IFS='|' read -r backend mode distro user base <<< "$context"
    mkdir -p "$_WINE_APP_STATE" || return 1
    if [ "$mode" = native ]; then
        runner="$_WINE_APP_STATE/$id.runner"
        stage=$(mktemp "${runner}.XXXXXX") || return 1
        # Keep the native implementation even if wine-box64 is later replaced by
        # a container wrapper. Hangover and Box64 prefixes remain independent.
        local source_runner="${PREFIX}/bin/wine-${backend}"
        if [ "$backend" = box64 ]; then
            if [ -x "${_WINE_BOX64_BIN}-native" ]; then
                source_runner="${_WINE_BOX64_BIN}-native"
            elif [[ "$(wine_backend_context box64)" = box64\|proot\|* ]]; then
                declare -F _wine_write_box64_native_wrapper >/dev/null || { rm -f "$stage"; return 1; }
                _wine_write_box64_native_wrapper "${_WINE_BOX64_BIN}-native" || { rm -f "$stage"; return 1; }
                source_runner="${_WINE_BOX64_BIN}-native"
            fi
        fi
        if ! cp "$source_runner" "$stage" || ! chmod +x "$stage" || ! mv -f "$stage" "$runner"; then
            rm -f "$stage"
            return 1
        fi
    fi
    _wine_context_write "$_WINE_APP_STATE/$id.context" "$context" || return 1
    wine_app_write_launcher "$id"
}

wine_app_is_installed() {
    local id="$1" context file
    [ -f "$PREFIX/share/applications/$id.desktop" ] || return 1
    context=$(wine_app_context "$id") || return 1
    file=$(_wine_app_file "$context" "$id") || return 1
    [ -f "$file" ] || return 1
    if [ ! -f "$_WINE_APP_STATE/$id.context" ] || [ ! -x "$PREFIX/bin/wine-app-$id" ]; then
        wine_app_record "$id" "$context" || return 1
    fi
}

wine_app_launch() {
    local id="$1" context rel backend mode distro user base
    shift
    context=$(wine_app_context "$id") || { echo '[ERROR] Wine 앱 설치 위치를 확인할 수 없습니다.' >&2; return 1; }
    rel=$(_wine_app_relpath "$id") || return 1
    IFS='|' read -r backend mode distro user base <<< "$context"
    if [ "$mode" = native ]; then
        [ -x "$_WINE_APP_STATE/$id.runner" ] || wine_app_record "$id" "$context" || return 1
        local WINE_CONTEXT_RUNNER="$_WINE_APP_STATE/$id.runner"
        export WINE_CONTEXT_RUNNER
    fi
    local windows='C:\'
    windows+="${rel//\//\\}"
    wine_exec_shell 'wine "$@"' "$context" "$windows" "$@"
}

wine_app_remove() {
    local id="$1" context rel directory
    rel=$(_wine_app_relpath "$id") || return 1
    context=$(wine_app_context "$id") || { echo '[ERROR] Wine 앱 설치 위치를 확인할 수 없습니다.' >&2; return 1; }
    directory="${rel%/*}"
    wine_exec_shell 'rm -rf -- "$WINEPREFIX/drive_c/$1"' "$context" "$directory" || return 1
    rm -f "$PREFIX/share/applications/$id.desktop" "$HOME/Desktop/$id.desktop" \
        "$PREFIX/bin/wine-app-$id" "$_WINE_APP_STATE/$id.context" "$_WINE_APP_STATE/$id.runner"
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
