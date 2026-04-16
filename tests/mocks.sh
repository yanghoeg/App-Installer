#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# MOCKS — app-installer 테스트용 스텁
# =============================================================================

MOCK_CALLS=()

_record_call() { MOCK_CALLS+=("$*"); }

reset_mock_calls() { MOCK_CALLS=(); }

assert_was_called() {
    local expected="$1"
    for call in "${MOCK_CALLS[@]:-}"; do
        [[ "$call" == *"$expected"* ]] && return 0
    done
    echo "[ASSERT] expected call containing '${expected}' not found in: ${MOCK_CALLS[*]:-<none>}" >&2
    return 1
}

assert_not_called() {
    local unexpected="$1"
    for call in "${MOCK_CALLS[@]:-}"; do
        if [[ "$call" == *"$unexpected"* ]]; then
            echo "[ASSERT] unexpected call found: ${call}" >&2
            return 1
        fi
    done
    return 0
}

# =============================================================================
# Mock: pkg_manager 포트 전체 (기록만 하고 실제 실행 안 함)
# =============================================================================

MOCK_INSTALLED_PKGS=""          # 설치된 것으로 취급할 패키지 (공백 구분)
MOCK_PROOT_INSTALLED_PKGS=""    # proot 내 설치 패키지
MOCK_HAS_PROOT=true             # has_proot_distro() 반환값

mock_pkg_adapter() {
    proot_exec()                  { _record_call "proot_exec $*"; }
    proot_exec_wine()             { _record_call "proot_exec_wine $*"; }
    proot_pkg_install()           { _record_call "proot_pkg_install $*"; }
    proot_pkg_remove()            { _record_call "proot_pkg_remove $*"; }
    proot_pkg_purge()             { _record_call "proot_pkg_purge $*"; }
    proot_pkg_update()            { _record_call "proot_pkg_update"; }
    proot_pkg_autoremove()        { _record_call "proot_pkg_autoremove"; }
    proot_pkg_is_installed()      { echo "$MOCK_PROOT_INSTALLED_PKGS" | grep -qw "$1"; }
    proot_pkg_install_aur()       { _record_call "proot_pkg_install_aur $*"; }
    proot_pkg_install_deb_or_aur(){ _record_call "proot_pkg_install_deb_or_aur $*"; }
    proot_pkg_add_external_repo() { _record_call "proot_pkg_add_external_repo $*"; }
    proot_dep()                   { _record_call "proot_dep $*"; }
    proot_dep_remove()            { _record_call "proot_dep_remove $*"; }
    proot_setup_bwrap()           { _record_call "proot_setup_bwrap"; }
    proot_pkg_install_sasm()      { _record_call "proot_pkg_install_sasm"; }
    proot_pkg_install_box64()     { _record_call "proot_pkg_install_box64"; }
    termux_pkg_install()          { _record_call "termux_pkg_install $*"; }
    termux_pkg_remove()           { _record_call "termux_pkg_remove $*"; }
    termux_pkg_is_installed()     { echo "$MOCK_INSTALLED_PKGS" | grep -qw "$1"; }

    has_proot_distro() { [ "${MOCK_HAS_PROOT}" = "true" ]; }
}

# =============================================================================
# Filesystem 샌드박스
# =============================================================================

setup_fs_sandbox() {
    local sandbox="$1"
    export HOME="${sandbox}/home"
    export PREFIX="${sandbox}/usr"
    export PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
    export PROOT_USER="${PROOT_USER:-testuser}"
    mkdir -p \
        "${HOME}/Desktop" \
        "${HOME}/.config/termux-xfce" \
        "${PREFIX}/share/applications" \
        "${PREFIX}/bin" \
        "${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/${PROOT_USER}" \
        "${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/usr/share/applications"
}
