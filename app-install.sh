#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# App Installer — CLI 인터페이스
# =============================================================================
# 사용법:
#   bash app-install.sh list                 — 전체 앱 목록 + 설치 상태
#   bash app-install.sh list <카테고리>      — 카테고리별 필터
#   bash app-install.sh install <id>         — 앱 설치
#   bash app-install.sh remove <id>          — 앱 제거
#   bash app-install.sh status <id>          — 설치 여부 확인
# 환경변수: PROOT_DISTRO, PROOT_USER (없으면 config 파일에서 로드)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# -----------------------------------------------------------------------------
# 설정 로드
# -----------------------------------------------------------------------------
_detect_proot_user() {
    local home_dir="${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO:-}/home"
    local d
    for d in "$home_dir"/*/; do
        [ -d "$d" ] || continue
        basename "$d"
        return
    done
    echo "user"
}

_load_config() {
    local config="$HOME/.config/termux-xfce/config"
    if [ -f "$config" ]; then
        source "$config"
    else
        PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
    fi
    PROOT_USER="${PROOT_USER:-$(_detect_proot_user)}"
}

_load_config

# -----------------------------------------------------------------------------
# DI: 포트 + 어댑터 로드
# -----------------------------------------------------------------------------
source "${SCRIPT_DIR}/ports/pkg_manager.sh"
source "${SCRIPT_DIR}/adapters/output/pkg_termux.sh"

case "${PROOT_DISTRO:-}" in
    ubuntu)    source "${SCRIPT_DIR}/adapters/output/pkg_ubuntu.sh" ;;
    archlinux) source "${SCRIPT_DIR}/adapters/output/pkg_arch.sh" ;;
    "")        ;;
    *)         echo "[WARN] 알 수 없는 PROOT_DISTRO: ${PROOT_DISTRO}" >&2 ;;
esac

# -----------------------------------------------------------------------------
# 도메인 로드
# -----------------------------------------------------------------------------
source "${SCRIPT_DIR}/domain/desktop.sh"
source "${SCRIPT_DIR}/domain/apps.sh"

for _installer in "${SCRIPT_DIR}/domain/installers/"*.sh; do
    source "$_installer"
done

# -----------------------------------------------------------------------------
# CLI 명령
# -----------------------------------------------------------------------------
_usage() {
    cat <<'USAGE'
사용법: app-install.sh <명령> [인자]

명령:
  list [카테고리]    전체 앱 목록 (카테고리 필터 가능)
  install <id>       앱 설치
  remove <id>        앱 제거
  status <id>        설치 여부 확인

예시:
  app-install.sh list
  app-install.sh list 개발
  app-install.sh install claude_code
  app-install.sh remove vlc
USAGE
}

_find_app() {
    local id="$1"
    for entry in "${APP_REGISTRY[@]}"; do
        IFS='|' read -r _id _name _category _desc <<< "$entry"
        [ "$_id" = "$id" ] && return 0
    done
    return 1
}

cmd_list() {
    local filter="${1:-}"
    printf "%-20s %-4s %-10s %s\n" "ID" "상태" "분류" "이름"
    printf '%.0s─' {1..60}; echo

    for entry in "${APP_REGISTRY[@]}"; do
        IFS='|' read -r _id _name _category _desc <<< "$entry"
        [ -n "$filter" ] && [ "$_category" != "$filter" ] && continue
        local mark="  "
        app_is_installed "$_id" && mark="✓ "
        printf "%-20s %-4s %-10s %s\n" "$_id" "$mark" "$_category" "$_name"
    done
}

cmd_install() {
    local id="$1"
    if ! _find_app "$id"; then
        echo "[ERROR] 알 수 없는 앱: $id" >&2
        echo "  app-install.sh list 로 ID를 확인하세요." >&2
        return 1
    fi
    if app_is_installed "$id"; then
        echo "[INFO] $id 는 이미 설치되어 있습니다."
        return 0
    fi
    echo "[INFO] $id 설치 시작..."
    if app_install "$id"; then
        echo "[OK] $id 설치 완료."
    else
        echo "[ERROR] $id 설치 실패." >&2
        return 1
    fi
}

cmd_remove() {
    local id="$1"
    if ! _find_app "$id"; then
        echo "[ERROR] 알 수 없는 앱: $id" >&2
        return 1
    fi
    if ! app_is_installed "$id"; then
        echo "[INFO] $id 는 설치되어 있지 않습니다."
        return 0
    fi
    echo "[INFO] $id 제거 시작..."
    if app_remove "$id"; then
        echo "[OK] $id 제거 완료."
    else
        echo "[ERROR] $id 제거 실패." >&2
        return 1
    fi
}

cmd_status() {
    local id="$1"
    if ! _find_app "$id"; then
        echo "[ERROR] 알 수 없는 앱: $id" >&2
        return 1
    fi
    if app_is_installed "$id"; then
        echo "$id: 설치됨"
    else
        echo "$id: 미설치"
    fi
}

# -----------------------------------------------------------------------------
# 메인
# -----------------------------------------------------------------------------
case "${1:-}" in
    list)    cmd_list "${2:-}" ;;
    install) [ -z "${2:-}" ] && { _usage; exit 1; }; cmd_install "$2" ;;
    remove)  [ -z "${2:-}" ] && { _usage; exit 1; }; cmd_remove "$2" ;;
    status)  [ -z "${2:-}" ] && { _usage; exit 1; }; cmd_status "$2" ;;
    *)       _usage; exit 1 ;;
esac
