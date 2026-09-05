#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# lib/common.sh — 하위 호환 래퍼
# =============================================================================
# 이 파일을 직접 source하던 기존 스크립트 호환성 유지용.
# 새 코드는 install.sh DI 컨테이너를 통해 어댑터를 로드할 것.

_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${_COMMON_DIR}/lib/proot_path.sh"

# install.sh / app-install.sh 공용 — proot 내부 rootfs의 home/ 아래 첫 사용자 디렉토리를
# 탐지. PROOT_DISTRO가 비어있으면(native only) 즉시 "user"로 폴백하고, 있으면
# for 루프(파이프라인 없음 — pipefail 아래에서도 안전)로 첫 디렉토리를 찾는다.
_detect_proot_user() {
    if [ -z "${PROOT_DISTRO:-}" ]; then
        echo "user"
        return
    fi
    local home_dir="$(_proot_rootfs)/home"
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
    if [ -z "${PROOT_USER:-}" ] && [ -n "${PROOT_DISTRO:-}" ]; then
        PROOT_USER=$(ls "$(_proot_rootfs)/home/" 2>/dev/null \
            | head -1 || echo "user")
    fi
    PROOT_USER="${PROOT_USER:-user}"

    # DI: 새 어댑터 로드
    source "${_COMMON_DIR}/ports/pkg_manager.sh"
    source "${_COMMON_DIR}/adapters/output/pkg_termux.sh"
    case "${PROOT_DISTRO:-}" in
        archlinux) source "${_COMMON_DIR}/adapters/output/pkg_arch.sh" ;;
        ubuntu)    source "${_COMMON_DIR}/adapters/output/pkg_ubuntu.sh" ;;
        "")        ;;  # native only — proot 포트는 미구현 stub 유지
        *)         echo "[WARN] 알 수 없는 PROOT_DISTRO: ${PROOT_DISTRO}" >&2 ;;
    esac
    source "${_COMMON_DIR}/domain/desktop.sh"
}

# 구 API → 새 API 매핑
_prun()           { proot_exec "$@"; }
_pkg_install()    { proot_pkg_install "$@"; }
_pkg_remove()     { proot_pkg_remove "$@"; }
_pkg_purge()      { proot_pkg_purge "$@"; }
_pkg_update()     { proot_pkg_update; }
_pkg_autoremove() { proot_pkg_autoremove; }
_aur_install()    { proot_pkg_install_aur "$@"; }
_pkg_install_deb_or_aur() { proot_pkg_install_deb_or_aur "$@"; }

_install_desktop() {
    local name="$1"
    cp "${PREFIX}/share/applications/${name}" "${HOME}/Desktop/${name}"
    chmod +x "${HOME}/Desktop/${name}"
}
