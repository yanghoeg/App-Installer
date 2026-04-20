#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# App Installer — 진입점 + DI 컨테이너
# =============================================================================
# 사용법: bash install.sh [wine]
#   wine  — Wine 앱만 표시 (Windows 프로그램 설치 UI)
# 환경변수: PROOT_DISTRO, PROOT_USER (없으면 config 파일에서 로드)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
_FILTER=""
case "${1:-}" in
    wine|Wine) _FILTER="Wine" ;;
esac

# -----------------------------------------------------------------------------
# 설정 로드
# -----------------------------------------------------------------------------
_load_config() {
    local config="$HOME/.config/termux-xfce/config"
    if [ -f "$config" ]; then
        source "$config"
        # config에 PROOT_DISTRO=""이면 그대로 유지 (사용자가 proot 없음 선택)
        # env var(PROOT_DISTRO=archlinux bash app-installer/install.sh)로 override 가능
    else
        # config 없을 때만 ubuntu 기본값 적용
        PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
    fi
    PROOT_USER="${PROOT_USER:-$(
        basename "${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/"* \
        2>/dev/null || echo "user"
    )}"
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
    "")        ;;  # proot 없음 (Termux native 전용)
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
# GUI 메인 루프 (yad 기반 — 앱 이름/설명 증분 검색 지원)
# -----------------------------------------------------------------------------
# Zink GPU 변수와 GTK font 렌더링 충돌 회피
unset MESA_LOADER_DRIVER_OVERRIDE TU_DEBUG ZINK_DESCRIPTORS \
      MESA_NO_ERROR MESA_GL_VERSION_OVERRIDE MESA_GLES_VERSION_OVERRIDE 2>/dev/null || true

export GTK_THEME=Adwaita:dark

# yad/zenity 자동 선택 (yad 우선)
if command -v yad >/dev/null 2>&1; then
    UI=yad
elif command -v zenity >/dev/null 2>&1; then
    UI=zenity
else
    echo "[ERROR] yad 또는 zenity가 필요합니다." >&2
    exit 1
fi

_notify_info() {
    local title="$1" body="$2"
    if [ "$UI" = yad ]; then
        yad --info --title="$title" --text="$body" --button=OK:0 --center --width=400 2>/dev/null || true
    else
        zenity --info --title="$title" --text="$body" 2>/dev/null || true
    fi
}
_notify_error() {
    local title="$1" body="$2"
    if [ "$UI" = yad ]; then
        yad --error --title="$title" --text="$body" --button=OK:0 --center --width=400 2>/dev/null || true
    else
        zenity --error --title="$title" --text="$body" 2>/dev/null || true
    fi
}

while true; do
    rows=()

    for _entry in "${APP_REGISTRY[@]}"; do
        IFS='|' read -r _id _name _category _desc <<< "$_entry"
        # Wine 필터: 설명에 "(Wine)" 포함된 항목만 표시
        if [ -n "$_FILTER" ] && [[ "$_desc" != *"($_FILTER)"* ]]; then
            continue
        fi
        if app_is_installed "$_id"; then
            _status="✅ 설치됨"
        else
            _status="⬜ 미설치"
        fi
        rows+=("$_status" "$_category" "$_name" "$_desc" "$_id")
    done

    local _title _text
    if [ -n "$_FILTER" ]; then
        _title="Wine App Installer"
        _text="Windows 프로그램을 선택하세요:"
    else
        _title="App Installer (proot: ${PROOT_DISTRO:-none}, user: ${PROOT_USER:-})"
        _text="앱을 검색/선택하세요 (이름/설명 입력 시 필터링):"
    fi

    if [ "$UI" = yad ]; then
        # --search-column=3: "이름" 컬럼 기준 타이핑 즉시 필터링
        # --print-column=5 : ID 컬럼(숨김) 반환
        # 타입(:TEXT/:HD)은 전체를 따옴표로 감싸야 일부 yad 빌드에서 안전하게 파싱됨
        chosen_id=$(yad --list \
            --title="$_title" \
            --text="$_text" \
            --column='상태:TEXT' \
            --column='카테고리:TEXT' \
            --column='이름:TEXT' \
            --column='설명:TEXT' \
            --column='ID:HD' \
            --search-column=3 \
            --print-column=5 \
            --separator="" \
            --width=1000 --height=600 --center \
            --button="설치/제거!gtk-apply:0" --button="취소!gtk-cancel:1" \
            "${rows[@]}" 2>/dev/null) || exit 0
    else
        # zenity fallback — 검색 기능 없음, 레거시 경로
        # rows는 5셀/행(상태,카테고리,이름,설명,ID)이므로 5개마다 "FALSE"(선택칼럼) 한 번만 삽입
        zenity_rows=()
        for ((_i=0; _i<${#rows[@]}; _i+=5)); do
            zenity_rows+=("FALSE" \
                "${rows[_i]}" "${rows[_i+1]}" "${rows[_i+2]}" "${rows[_i+3]}" "${rows[_i+4]}")
        done
        chosen_id=$(zenity --list --radiolist \
            --title="$_title" \
            --text="$_text" \
            --column="Select" --column="상태" --column="카테고리" --column="이름" --column="설명" --column="ID" \
            --hide-column=6 --print-column=6 \
            "${zenity_rows[@]}" \
            --width=1000 --height=600 2>/dev/null) || exit 0
    fi

    [ -z "$chosen_id" ] && continue

    if app_is_installed "$chosen_id"; then
        if app_remove "$chosen_id"; then
            _notify_info "제거 완료" "${chosen_id} 제거가 완료되었습니다."
        else
            _notify_error "오류" "${chosen_id} 제거 중 오류가 발생했습니다."
        fi
    else
        if app_install "$chosen_id"; then
            _notify_info "설치 완료" "${chosen_id} 설치가 완료되었습니다."
        else
            _notify_error "오류" "${chosen_id} 설치 중 오류가 발생했습니다."
        fi
    fi
done
