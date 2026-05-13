#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# App Installer — 진입점 + DI 컨테이너
# =============================================================================
# 사용법: bash install.sh [wine]
#   wine  — Wine 탭만 단독 표시 (Windows 프로그램 설치 UI)
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
# GUI
# -----------------------------------------------------------------------------
unset MESA_LOADER_DRIVER_OVERRIDE TU_DEBUG ZINK_DESCRIPTORS \
      MESA_NO_ERROR MESA_GL_VERSION_OVERRIDE MESA_GLES_VERSION_OVERRIDE 2>/dev/null || true

export GTK_THEME=Adwaita:dark

if command -v yad >/dev/null 2>&1; then
    UI=yad
elif command -v zenity >/dev/null 2>&1; then
    UI=zenity
else
    echo "[ERROR] yad 또는 zenity가 필요합니다." >&2
    exit 1
fi

_notify() {
    local type="$1" title="$2" body="$3"
    if [ "$UI" = yad ]; then
        yad --"$type" --title="$title" --text="$body" --button=OK:0 \
            --center --width=420 --borders=20 2>/dev/null || true
    else
        zenity --"$type" --title="$title" --text="$body" 2>/dev/null || true
    fi
}

# 카테고리가 탭 그룹에 속하는지 확인
_category_in_tab() {
    local category="$1" tab_categories="$2"
    IFS=',' read -ra _cats <<< "$tab_categories"
    for _c in "${_cats[@]}"; do
        [ "$_c" = "$category" ] && return 0
    done
    return 1
}

# 앱 상태 아이콘
_status_icon() {
    if app_is_installed "$1"; then
        echo "✅"
    else
        echo "⬜"
    fi
}

# -----------------------------------------------------------------------------
# yad notebook 탭 GUI
# -----------------------------------------------------------------------------
_run_yad_notebook() {
    local _KEY=$$
    local _title="App Installer"
    local _subtitle="proot: ${PROOT_DISTRO:-none} · user: ${PROOT_USER:-}"

    # Wine 필터 모드 — 단일 리스트, 탭 없음
    if [ -n "$_FILTER" ]; then
        _run_yad_flat "Wine App Installer" "Windows 프로그램을 선택하세요:"
        return
    fi

    # 각 탭별 리스트를 plug 자식 프로세스로 생성
    local _tab_num=0
    local _tab_args=()
    for _group in "${TAB_GROUPS[@]}"; do
        IFS='|' read -r _tab_label _tab_cats <<< "$_group"
        _tab_num=$((_tab_num + 1))
        _tab_args+=(--tab="$_tab_label")

        (
            local rows=()
            for _entry in "${APP_REGISTRY[@]}"; do
                IFS='|' read -r _id _name _category _desc <<< "$_entry"
                _category_in_tab "$_category" "$_tab_cats" || continue
                rows+=("$(_status_icon "$_id")" "$_category" "$_name" "$_desc" "$_id")
            done

            [ ${#rows[@]} -gt 0 ] && yad --plug=$_KEY --tabnum=$_tab_num --list \
                --column='  :TEXT' \
                --column='분류:TEXT' \
                --column='이름:TEXT' \
                --column='설명:TEXT' \
                --column='ID:HD' \
                --search-column=3 \
                --print-column=5 \
                --separator="" \
                --tooltip-column=4 \
                --expand-column=4 \
                --no-click \
                "${rows[@]}" 2>/dev/null
        ) &
    done

    # Wine 탭 (별도)
    _tab_num=$((_tab_num + 1))
    _tab_args+=(--tab="Wine")
    (
        local rows=()
        for _entry in "${APP_REGISTRY[@]}"; do
            IFS='|' read -r _id _name _category _desc <<< "$_entry"
            [[ "$_desc" == *"(Wine)"* ]] || [ "$_id" = "wine" ] || continue
            rows+=("$(_status_icon "$_id")" "$_category" "$_name" "$_desc" "$_id")
        done

        [ ${#rows[@]} -gt 0 ] && yad --plug=$_KEY --tabnum=$_tab_num --list \
            --column='  :TEXT' \
            --column='분류:TEXT' \
            --column='이름:TEXT' \
            --column='설명:TEXT' \
            --column='ID:HD' \
            --search-column=3 \
            --print-column=5 \
            --separator="" \
            --tooltip-column=4 \
            --expand-column=4 \
            --no-click \
            "${rows[@]}" 2>/dev/null
    ) &

    # notebook 부모
    local result
    result=$(yad --notebook --key=$_KEY \
        "${_tab_args[@]}" \
        --tab-pos=top \
        --title="$_title" \
        --text="$_subtitle" \
        --width=1000 --height=620 --center --borders=8 \
        --button="설치/제거!gtk-apply:0" \
        --button="닫기!gtk-cancel:1" \
        2>/dev/null) || return 1

    # 선택된 ID 추출 — notebook은 모든 탭 출력을 반환하므로
    # 비어 있지 않은 첫 번째 ID만 취함
    echo "$result" | tr -d '|' | awk 'NF{print;exit}' | tr -d '[:space:]'
}

# Wine 전용 또는 zenity 폴백용 단일 리스트
_run_yad_flat() {
    local _title="$1" _text="$2"
    local rows=()

    for _entry in "${APP_REGISTRY[@]}"; do
        IFS='|' read -r _id _name _category _desc <<< "$_entry"
        if [ -n "$_FILTER" ] && [[ "$_desc" != *"($_FILTER)"* ]] && [ "$_id" != "wine" ]; then
            continue
        fi
        rows+=("$(_status_icon "$_id")" "$_category" "$_name" "$_desc" "$_id")
    done

    yad --list \
        --title="$_title" \
        --text="$_text" \
        --column='  :TEXT' \
        --column='분류:TEXT' \
        --column='이름:TEXT' \
        --column='설명:TEXT' \
        --column='ID:HD' \
        --search-column=3 \
        --print-column=5 \
        --separator="" \
        --tooltip-column=4 \
        --expand-column=4 \
        --no-click \
        --width=1000 --height=600 --center --borders=8 \
        --button="설치/제거!gtk-apply:0" --button="닫기!gtk-cancel:1" \
        "${rows[@]}" 2>/dev/null
}

# zenity 폴백 (탭 미지원)
_run_zenity() {
    local _title="App Installer (proot: ${PROOT_DISTRO:-none}, user: ${PROOT_USER:-})"
    local zenity_rows=()

    for _entry in "${APP_REGISTRY[@]}"; do
        IFS='|' read -r _id _name _category _desc <<< "$_entry"
        if [ -n "$_FILTER" ] && [[ "$_desc" != *"($_FILTER)"* ]] && [ "$_id" != "wine" ]; then
            continue
        fi
        zenity_rows+=("FALSE" "$(_status_icon "$_id")" "$_category" "$_name" "$_desc" "$_id")
    done

    zenity --list --radiolist \
        --title="$_title" \
        --text="앱을 선택하세요:" \
        --column="Select" --column="상태" --column="분류" --column="이름" --column="설명" --column="ID" \
        --hide-column=6 --print-column=6 \
        "${zenity_rows[@]}" \
        --width=1000 --height=600 2>/dev/null
}

# -----------------------------------------------------------------------------
# 메인 루프
# -----------------------------------------------------------------------------
while true; do
    if [ "$UI" = yad ]; then
        chosen_id=$(_run_yad_notebook) || exit 0
    else
        chosen_id=$(_run_zenity) || exit 0
    fi

    [ -z "$chosen_id" ] && continue

    if app_is_installed "$chosen_id"; then
        if app_remove "$chosen_id"; then
            _notify info "제거 완료" "${chosen_id} 제거가 완료되었습니다."
        else
            _notify error "오류" "${chosen_id} 제거 중 오류가 발생했습니다."
        fi
    else
        if app_install "$chosen_id"; then
            _notify info "설치 완료" "${chosen_id} 설치가 완료되었습니다."
        else
            _notify error "오류" "${chosen_id} 설치 중 오류가 발생했습니다."
        fi
    fi
done
