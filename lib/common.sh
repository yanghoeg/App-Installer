#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# lib/common.sh — 하위 호환 래퍼
# =============================================================================
# 이 파일을 직접 source하던 기존 스크립트 호환성 유지용.
# 새 코드는 install.sh DI 컨테이너를 통해 어댑터를 로드할 것.

_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

_load_config() {
    local config="$HOME/.config/termux-xfce/config"
    [ -f "$config" ] && source "$config"
    PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
    PROOT_USER="${PROOT_USER:-$(
        basename "${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/"* \
        2>/dev/null || echo "user"
    )}"

    # DI: 새 어댑터 로드
    source "${_COMMON_DIR}/ports/pkg_manager.sh"
    source "${_COMMON_DIR}/adapters/output/pkg_termux.sh"
    case "${PROOT_DISTRO}" in
        archlinux) source "${_COMMON_DIR}/adapters/output/pkg_arch.sh" ;;
        *)         source "${_COMMON_DIR}/adapters/output/pkg_ubuntu.sh" ;;
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
