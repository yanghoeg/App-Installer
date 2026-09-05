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
    proot_exec()                  {
        _record_call "proot_exec $*"
        if [ "${1:-}" = "which" ]; then
            echo "$MOCK_PROOT_INSTALLED_PKGS" | grep -qw "${2:-}"
        fi
    }
    proot_exec_wine()             { _record_call "proot_exec_wine $*"; }
    proot_pkg_install()           { _record_call "proot_pkg_install $*"; }
    proot_pkg_remove()            { _record_call "proot_pkg_remove $*"; }
    proot_pkg_purge()             { _record_call "proot_pkg_purge $*"; }
    proot_pkg_update()            { _record_call "proot_pkg_update"; }
    proot_pkg_autoremove()        { _record_call "proot_pkg_autoremove"; }
    proot_pkg_is_installed()      { echo "$MOCK_PROOT_INSTALLED_PKGS" | grep -qw "$1"; }
    proot_pkg_install_aur()       { _record_call "proot_pkg_install_aur $*"; }
    proot_pkg_install_deb_or_aur(){ _record_call "proot_pkg_install_deb_or_aur $*"; }
    proot_pkg_install_deb_url()   { _record_call "proot_pkg_install_deb_url $*"; }
    proot_pkg_add_external_repo() { _record_call "proot_pkg_add_external_repo $*"; }
    proot_pkg_install_libreoffice(){ _record_call "proot_pkg_install_libreoffice"; }
    proot_pkg_remove_libreoffice() { _record_call "proot_pkg_remove_libreoffice"; }
    proot_pkg_install_jdk()       { _record_call "proot_pkg_install_jdk"; }
    proot_pkg_install_python_pip(){ _record_call "proot_pkg_install_python_pip"; }
    proot_pkg_install_zlib()      { _record_call "proot_pkg_install_zlib"; }
    proot_pkg_install_sasm()      { _record_call "proot_pkg_install_sasm"; }
    proot_pkg_install_box64()     {
        _record_call "proot_pkg_install_box64"
        MOCK_PROOT_INSTALLED_PKGS="${MOCK_PROOT_INSTALLED_PKGS} box64"
    }
    proot_pkg_install_wine_mesa() { _record_call "proot_pkg_install_wine_mesa"; }
    proot_pkg_install_tor_deps()  { _record_call "proot_pkg_install_tor_deps"; }
    proot_pkg_install_vscode()    {
        _record_call "proot_pkg_add_external_repo vscode"
        _record_call "proot_pkg_install code"
    }
    proot_pkg_remove_vscode()     { _record_call "proot_pkg_remove_vscode"; }
    proot_setup_bwrap()           { _record_call "proot_setup_bwrap"; }
    termux_pkg_install()          { _record_call "termux_pkg_install $*"; }
    termux_pkg_remove()           { _record_call "termux_pkg_remove $*"; }
    termux_pkg_is_installed()     { echo "$MOCK_INSTALLED_PKGS" | grep -qw "$1"; }
    termux_pkg_enable_repo()      {
        _record_call "termux_pkg_enable_repo $*"
        echo "$MOCK_INSTALLED_PKGS" | grep -qw "$1" && return 0
        MOCK_INSTALLED_PKGS="${MOCK_INSTALLED_PKGS} $1"
    }

    has_proot_distro() { [ "${MOCK_HAS_PROOT}" = "true" ]; }
}

# =============================================================================
# Mock: 모든 설치 계열 primitive가 실패 — 설치기 계약 테스트용
# app_install_<id>는 이 mock 하에서 반드시 non-zero를 반환해야 하고
# .desktop 런처를 생성하지 않아야 한다 (domain/apps.sh app_install() 계약 주석 참조).
# =============================================================================

mock_all_install_primitives_fail() {
    mock_pkg_adapter   # 레코딩 스타일 기본값을 먼저 깔고, 설치 계열만 실패로 override

    proot_exec()                    { _record_call "proot_exec $*"; return 1; }
    proot_exec_wine()               { _record_call "proot_exec_wine $*"; return 1; }
    proot_pkg_install()             { _record_call "proot_pkg_install $*"; return 1; }
    proot_pkg_update()              { _record_call "proot_pkg_update"; return 1; }
    proot_pkg_install_aur()         { _record_call "proot_pkg_install_aur $*"; return 1; }
    proot_pkg_install_deb_or_aur()  { _record_call "proot_pkg_install_deb_or_aur $*"; return 1; }
    proot_pkg_install_deb_url()     { _record_call "proot_pkg_install_deb_url $*"; return 1; }
    proot_pkg_add_external_repo()   { _record_call "proot_pkg_add_external_repo $*"; return 1; }
    proot_pkg_install_libreoffice() { _record_call "proot_pkg_install_libreoffice"; return 1; }
    proot_pkg_install_jdk()         { _record_call "proot_pkg_install_jdk"; return 1; }
    proot_pkg_install_python_pip()  { _record_call "proot_pkg_install_python_pip"; return 1; }
    proot_pkg_install_zlib()        { _record_call "proot_pkg_install_zlib"; return 1; }
    proot_pkg_install_sasm()        { _record_call "proot_pkg_install_sasm"; return 1; }
    proot_pkg_install_box64()       { _record_call "proot_pkg_install_box64"; return 1; }
    proot_pkg_install_wine_mesa()   { _record_call "proot_pkg_install_wine_mesa"; return 1; }
    proot_pkg_install_tor_deps()    { _record_call "proot_pkg_install_tor_deps"; return 1; }
    proot_pkg_install_vscode()      { _record_call "proot_pkg_install_vscode"; return 1; }
    proot_setup_bwrap()             { _record_call "proot_setup_bwrap"; return 1; }

    termux_pkg_install()            { _record_call "termux_pkg_install $*"; return 1; }
    termux_pkg_enable_repo()        { _record_call "termux_pkg_enable_repo $*"; return 1; }

    # MOCK_HAS_PROOT을 그대로 존중 — 호출부가 true로 둬야 proot 설치기가
    # "proot 없음" 조기 에러가 아니라 실제 critical 명령까지 도달한다.
    has_proot_distro() { [ "${MOCK_HAS_PROOT}" = "true" ]; }

    # 포트를 거치지 않고 설치기가 직접 부르는 실제 외부 명령
    curl()  { return 1; }
    wget()  { return 1; }
    git()   { return 1; }
    pip()   { return 1; }
    pip3()  { return 1; }
    npm()   { return 1; }
    cargo() { return 1; }

    wine_exec_shell() { _record_call "wine_exec_shell $*"; return 1; }
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
