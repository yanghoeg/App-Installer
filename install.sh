#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# App Installer — 진입점 + DI 컨테이너
# =============================================================================
# 사용법: bash install.sh
# 환경변수: PROOT_DISTRO, PROOT_USER (없으면 config 파일에서 로드)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
# GUI 메인 루프
# -----------------------------------------------------------------------------
# zenity/GTK 텍스트 렌더링 버그 회피: Zink GPU 변수와 GTK font 렌더링 충돌
unset MESA_LOADER_DRIVER_OVERRIDE TU_DEBUG ZINK_DESCRIPTORS \
      MESA_NO_ERROR MESA_GL_VERSION_OVERRIDE MESA_GLES_VERSION_OVERRIDE 2>/dev/null || true

export GTK_THEME=Adwaita:dark

while true; do
    rows=()
    row_ids=()

    for _entry in "${APP_REGISTRY[@]}"; do
        IFS='|' read -r _id _name _desc <<< "$_entry"
        if app_is_installed "$_id"; then
            _action="Remove ${_name} (Installed)"
        else
            _action="Install ${_name} (Not Installed)"
        fi
        rows+=("FALSE" "$_action" "$_desc" "$_id")
        row_ids+=("${_action}:${_id}")
    done

    # --hide-column=4: app_id 컬럼 숨김
    # --print-column=4: 선택 시 app_id 반환
    chosen_id=$(zenity --list --radiolist \
        --title="App Installer (proot: ${PROOT_DISTRO:-none}, user: ${PROOT_USER:-})" \
        --text="앱을 선택하세요:" \
        --column="Select" --column="Action" --column="Description" --column="ID" \
        --hide-column=4 \
        --print-column=4 \
        "${rows[@]}" \
        --width=900 --height=500 2>/dev/null) || exit 0

    [ -z "$chosen_id" ] && continue

    if app_is_installed "$chosen_id"; then
        if app_remove "$chosen_id"; then
            zenity --info --title="제거 완료" \
                --text="${chosen_id} 제거가 완료되었습니다." 2>/dev/null || true
        else
            zenity --error --title="오류" \
                --text="${chosen_id} 제거 중 오류가 발생했습니다." 2>/dev/null || true
        fi
    else
        if app_install "$chosen_id"; then
            zenity --info --title="설치 완료" \
                --text="${chosen_id} 설치가 완료되었습니다." 2>/dev/null || true
        else
            zenity --error --title="오류" \
                --text="${chosen_id} 설치 중 오류가 발생했습니다." 2>/dev/null || true
        fi
    fi
done
