#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# TEST: 포트 계약 — 모든 어댑터가 포트 함수를 구현하는지 검증
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/.."
source "${SCRIPT_DIR}/framework.sh"

# 모든 어댑터가 구현해야 할 포트 함수 목록
# 단순 패키지명 차이는 PROOT_DEP_MAP + proot_dep()로 추상화 →
# 개별 wrapper(jdk, python_pip, zlib, libreoffice, wine_mesa, tor_deps) 제거
PKG_PROOT_CONTRACTS=(
    proot_exec
    proot_exec_wine
    proot_pkg_install
    proot_pkg_remove
    proot_pkg_purge
    proot_pkg_update
    proot_pkg_autoremove
    proot_pkg_is_installed
    proot_pkg_install_aur
    proot_pkg_install_deb_or_aur
    proot_pkg_add_external_repo
    proot_pkg_install_sasm
    proot_pkg_install_box64
    proot_dep
    proot_dep_remove
    proot_setup_bwrap
)

PKG_TERMUX_CONTRACTS=(
    termux_pkg_install
    termux_pkg_remove
    termux_pkg_is_installed
)

_check_contracts() {
    local adapter_file="$1"; shift
    local contracts=("$@")
    (
        # 서브셸에서 source — 현재 환경 오염 방지
        source "$adapter_file" 2>/dev/null
        for fn in "${contracts[@]}"; do
            if ! declare -f "$fn" >/dev/null 2>&1; then
                echo "[ASSERT] '${fn}' not declared in $(basename "$adapter_file")" >&2
                exit 1
            fi
        done
    )
}

# =============================================================================
# pkg_termux.sh 계약
# =============================================================================
describe "포트 계약 — adapters/output/pkg_termux.sh"

_test_termux_contracts() {
    _check_contracts "${APP_DIR}/adapters/output/pkg_termux.sh" "${PKG_TERMUX_CONTRACTS[@]}"
}
it "모든 termux_pkg_* 계약을 구현한다" _test_termux_contracts

# =============================================================================
# pkg_ubuntu.sh 계약
# =============================================================================
describe "포트 계약 — adapters/output/pkg_ubuntu.sh"

_test_ubuntu_contracts() {
    _check_contracts "${APP_DIR}/adapters/output/pkg_ubuntu.sh" \
        "${PKG_PROOT_CONTRACTS[@]}"
}
it "모든 proot_pkg_* 계약을 구현한다" _test_ubuntu_contracts

# =============================================================================
# pkg_arch.sh 계약
# =============================================================================
describe "포트 계약 — adapters/output/pkg_arch.sh"

_test_arch_contracts() {
    _check_contracts "${APP_DIR}/adapters/output/pkg_arch.sh" \
        "${PKG_PROOT_CONTRACTS[@]}"
}
it "모든 proot_pkg_* 계약을 구현한다" _test_arch_contracts

# =============================================================================
# ports/pkg_manager.sh — 미구현 함수는 오류 반환
# =============================================================================
describe "포트 — 미구현 함수 오류 동작"

_test_port_not_impl_returns_error() {
    (
        source "${APP_DIR}/ports/pkg_manager.sh"
        proot_exec echo "should not run" 2>/dev/null
    )
    assert_nonzero $? "미구현 proot_exec는 0이 아닌 코드를 반환해야 한다"
}
it "어댑터 없이 proot_exec 호출 시 오류 반환" _test_port_not_impl_returns_error

_test_termux_port_not_impl_returns_error() {
    (
        source "${APP_DIR}/ports/pkg_manager.sh"
        termux_pkg_install "somepackage" 2>/dev/null
    )
    assert_nonzero $? "미구현 termux_pkg_install는 0이 아닌 코드를 반환해야 한다"
}
it "어댑터 없이 termux_pkg_install 호출 시 오류 반환" _test_termux_port_not_impl_returns_error

# =============================================================================
# 어댑터 override 검증 — ubuntu/arch는 no-op이 아닌 실제 구현을 제공
# =============================================================================
describe "어댑터 override — 포트 기본값 미사용"

_test_ubuntu_overrides_proot_exec() {
    (
        source "${APP_DIR}/ports/pkg_manager.sh"
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        # proot_exec가 제대로 override 되었으면 선언되어 있어야 함
        declare -f proot_exec | grep -q "proot-distro"
    )
}
it "pkg_ubuntu.sh의 proot_exec는 proot-distro를 호출한다" _test_ubuntu_overrides_proot_exec

_test_arch_overrides_proot_pkg_install() {
    (
        source "${APP_DIR}/ports/pkg_manager.sh"
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        declare -f proot_pkg_install | grep -q "pacman"
    )
}
it "pkg_arch.sh의 proot_pkg_install은 pacman을 호출한다" _test_arch_overrides_proot_pkg_install

_test_ubuntu_proot_install_uses_apt() {
    (
        source "${APP_DIR}/ports/pkg_manager.sh"
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        declare -f proot_pkg_install | grep -q "apt"
    )
}
it "pkg_ubuntu.sh의 proot_pkg_install은 apt를 호출한다" _test_ubuntu_proot_install_uses_apt

# =============================================================================
# distro별 패키지명 분기 — PROOT_DEP_MAP 해석 검증
# =============================================================================
describe "어댑터 — PROOT_DEP_MAP distro별 패키지명"

# entry 포맷 "key:pkg1 pkg2..." 에서 key가 일치하는 항목의 pkg 문자열 추출
_lookup_dep() {
    local key="$1"
    for e in "${PROOT_DEP_MAP[@]}"; do
        if [[ "${e%%:*}" == "$key" ]]; then
            echo "${e#*:}"
            return 0
        fi
    done
    return 1
}

_test_ubuntu_libreoffice_dep_map() {
    (
        source "${APP_DIR}/ports/pkg_manager.sh"
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        local pkgs; pkgs=$(_lookup_dep "libreoffice")
        # Ubuntu는 'libreoffice' (fresh 접미사 없음)
        [[ "$pkgs" == "libreoffice" ]]
    )
}
it "Ubuntu: PROOT_DEP_MAP[libreoffice] = 'libreoffice' (not fresh)" _test_ubuntu_libreoffice_dep_map

_test_arch_libreoffice_dep_map() {
    (
        source "${APP_DIR}/ports/pkg_manager.sh"
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        local pkgs; pkgs=$(_lookup_dep "libreoffice")
        [[ "$pkgs" == *"libreoffice-fresh"* ]]
    )
}
it "Arch: PROOT_DEP_MAP[libreoffice] = 'libreoffice-fresh'" _test_arch_libreoffice_dep_map

_test_ubuntu_jdk_dep_map() {
    (
        source "${APP_DIR}/ports/pkg_manager.sh"
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        local pkgs; pkgs=$(_lookup_dep "jdk")
        [[ "$pkgs" == *"openjdk"* ]]
    )
}
it "Ubuntu: PROOT_DEP_MAP[jdk] → openjdk-* 계열" _test_ubuntu_jdk_dep_map

_test_arch_jdk_dep_map() {
    (
        source "${APP_DIR}/ports/pkg_manager.sh"
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        local pkgs; pkgs=$(_lookup_dep "jdk")
        [[ "$pkgs" == *"jdk"* ]]
    )
}
it "Arch: PROOT_DEP_MAP[jdk] → jdk-openjdk 계열" _test_arch_jdk_dep_map

_test_proot_dep_resolves_via_map() {
    (
        source "${APP_DIR}/ports/pkg_manager.sh"
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        # proot_pkg_install 호출을 가로채서 해석된 패키지 기록
        RESOLVED=""
        proot_pkg_install() { RESOLVED="$*"; }
        proot_dep "jdk" >/dev/null 2>&1
        [[ "$RESOLVED" == "openjdk-21-jdk" ]]
    )
}
it "proot_dep → PROOT_DEP_MAP 조회 후 proot_pkg_install 위임" _test_proot_dep_resolves_via_map

_test_proot_dep_unknown_key_fails() {
    (
        source "${APP_DIR}/ports/pkg_manager.sh"
        source "${APP_DIR}/adapters/output/pkg_ubuntu.sh"
        proot_pkg_install() { :; }
        proot_dep "nonexistent_key" 2>/dev/null
        [ $? -ne 0 ]
    )
}
it "proot_dep → 알 수 없는 키 시 오류 반환" _test_proot_dep_unknown_key_fails

_test_arch_add_external_repo_is_noop() {
    (
        source "${APP_DIR}/ports/pkg_manager.sh"
        source "${APP_DIR}/adapters/output/pkg_arch.sh"
        # Arch의 add_external_repo는 에러 없이 종료해야 함 (no-op)
        PROOT_DISTRO=archlinux PROOT_USER=user
        proot_pkg_add_external_repo "test" "http://example.com/key" "deb ..." 2>/dev/null
    )
}
it "Arch: proot_pkg_add_external_repo는 오류 없이 no-op" _test_arch_add_external_repo_is_noop

print_results
