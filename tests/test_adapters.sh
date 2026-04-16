#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# TEST: 어댑터 구현 검증 (실제 명령 실행 없이 선언·구조만 검사)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/.."
source "${SCRIPT_DIR}/framework.sh"

# =============================================================================
# pkg_termux.sh — Termux native
# =============================================================================
describe "pkg_termux.sh — 구현 검증"

_test_termux_install_uses_pkg() {
    (
        source "${APP_DIR}/adapters/output/pkg_termux.sh"
        declare -f termux_pkg_install | grep -q "pkg install"
    )
}
it "termux_pkg_install → 'pkg install -y' 사용" _test_termux_install_uses_pkg

_test_termux_remove_uses_uninstall() {
    (
        source "${APP_DIR}/adapters/output/pkg_termux.sh"
        declare -f termux_pkg_remove | grep -q "pkg uninstall"
    )
}
it "termux_pkg_remove → 'pkg uninstall -y' 사용" _test_termux_remove_uses_uninstall

_test_termux_is_installed_checks_list() {
    (
        source "${APP_DIR}/adapters/output/pkg_termux.sh"
        declare -f termux_pkg_is_installed | grep -q "list-installed"
    )
}
it "termux_pkg_is_installed → 'pkg list-installed' 사용" _test_termux_is_installed_checks_list

# =============================================================================
# pkg_ubuntu.sh — proot Ubuntu
# =============================================================================
describe "pkg_ubuntu.sh — 구현 검증"

_test_ubuntu_exec_uses_proot_distro_login() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        declare -f proot_exec | grep -q "proot-distro login"
    )
}
it "proot_exec → proot-distro login 사용" _test_ubuntu_exec_uses_proot_distro_login

_test_ubuntu_exec_wine_has_mesa_env() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        declare -f proot_exec_wine | grep -q "MESA_LOADER_DRIVER_OVERRIDE"
    )
}
it "proot_exec_wine → MESA_LOADER_DRIVER_OVERRIDE 포함" _test_ubuntu_exec_wine_has_mesa_env

_test_ubuntu_sasm_has_codename_workaround() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        # noble/oracular/plucky를 mantic으로 교체하는 로직이 있어야 함
        declare -f proot_pkg_install_sasm | grep -q "mantic"
    )
}
it "proot_pkg_install_sasm → Ubuntu codename 폴백 포함" _test_ubuntu_sasm_has_codename_workaround

_test_ubuntu_add_repo_uses_gpg() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        declare -f proot_pkg_add_external_repo | grep -q "gpg"
    )
}
it "proot_pkg_add_external_repo → GPG 키 처리 포함" _test_ubuntu_add_repo_uses_gpg

_test_ubuntu_dep_map_defined() {
    (
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        # PROOT_DEP_MAP이 Ubuntu 어댑터에서 정의되고 핵심 키를 포함해야 함
        [ "${#PROOT_DEP_MAP[@]}" -gt 0 ] && \
        printf '%s\n' "${PROOT_DEP_MAP[@]}" | grep -q '^jdk:' && \
        printf '%s\n' "${PROOT_DEP_MAP[@]}" | grep -q '^libreoffice:' && \
        printf '%s\n' "${PROOT_DEP_MAP[@]}" | grep -q '^mesa_vulkan:'
    )
}
it "PROOT_DEP_MAP 정의 + jdk/libreoffice/mesa_vulkan 키 포함" _test_ubuntu_dep_map_defined

# =============================================================================
# pkg_arch.sh — proot Arch
# =============================================================================
describe "pkg_arch.sh — 구현 검증"

_test_arch_exec_uses_proot_distro_login() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        declare -f proot_exec | grep -q "proot-distro login"
    )
}
it "proot_exec → proot-distro login 사용" _test_arch_exec_uses_proot_distro_login

_test_arch_autoremove_handles_orphans() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        declare -f proot_pkg_autoremove | grep -q "orphans"
    )
}
it "proot_pkg_autoremove → pacman orphan 처리" _test_arch_autoremove_handles_orphans

_test_arch_aur_installs_yay_if_missing() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        declare -f proot_pkg_install_aur | grep -q "yay"
    )
}
it "proot_pkg_install_aur → yay 없으면 자동 설치" _test_arch_aur_installs_yay_if_missing

_test_arch_box64_tries_chaotic_aur() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        declare -f proot_pkg_install_box64 | grep -q "chaotic"
    )
}
it "proot_pkg_install_box64 → Chaotic-AUR 폴백 있음" _test_arch_box64_tries_chaotic_aur

_test_arch_deb_or_aur_delegates_to_aur() {
    (
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        declare -f proot_pkg_install_deb_or_aur | grep -q "proot_pkg_install_aur"
    )
}
it "proot_pkg_install_deb_or_aur → Arch는 AUR에 위임" _test_arch_deb_or_aur_delegates_to_aur

# =============================================================================
# lib/common.sh — 하위 호환 래퍼
# =============================================================================
describe "lib/common.sh — 하위 호환 API"

_test_common_exposes_legacy_api() {
    (
        source "${APP_DIR}/lib/common.sh" 2>/dev/null || true
        declare -f _prun >/dev/null 2>&1 && \
        declare -f _pkg_install >/dev/null 2>&1 && \
        declare -f _pkg_remove >/dev/null 2>&1 && \
        declare -f _load_config >/dev/null 2>&1
    )
}
it "_prun, _pkg_install, _pkg_remove, _load_config 함수 존재" _test_common_exposes_legacy_api

print_results
