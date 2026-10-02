#!/data/data/com.termux/files/usr/bin/bash
# Recovery and publication regressions: all package/download/proot commands are mocked.
_ALL_CORE_APP="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
source "$_ALL_CORE_APP/tests/framework.sh"

_all_core_setup() {
    _ALL_CORE_SB=$(make_sandbox)
    trap 'cleanup_sandbox "$_ALL_CORE_SB"' EXIT
    export HOME="$_ALL_CORE_SB/home" PREFIX="$_ALL_CORE_SB/usr" TMPDIR="$_ALL_CORE_SB/tmp"
    mkdir -p "$HOME/Desktop" "$PREFIX/bin" "$PREFIX/share/applications" "$TMPDIR"
    gio() { return 1; }
}

_all_package_states() {
    case "${@: -1}" in
        exact) printf 'install ok installed' ;;
        held) printf 'hold ok installed' ;;
        removed) printf 'deinstall ok config-files' ;;
        broken) printf 'install ok half-configured' ;;
        reinst-required) printf 'install reinstreq installed' ;;
        *) return 1 ;;
    esac
}

_test_all_termux_exact_state() {
    _all_core_setup
    source "$_ALL_CORE_APP/adapters/output/pkg_termux.sh"
    pkg() { echo 'package listing must not be used' >&2; return 99; }
    dpkg-query() { _all_package_states "$@"; }
    termux_pkg_is_installed exact
    termux_pkg_is_installed held
    if termux_pkg_is_installed removed || termux_pkg_is_installed broken ||
       termux_pkg_is_installed missing || termux_pkg_is_installed exact-extra ||
       termux_pkg_is_installed reinst-required; then return 1; fi
}

_test_all_ubuntu_exact_state() {
    _all_core_setup
    source "$_ALL_CORE_APP/adapters/output/pkg_ubuntu.sh"
    proot_exec() { "$@"; }
    dpkg-query() { _all_package_states "$@"; }
    proot_pkg_is_installed exact
    proot_pkg_is_installed held
    if proot_pkg_is_installed removed || proot_pkg_is_installed broken ||
       proot_pkg_is_installed missing || proot_pkg_is_installed reinst-required; then return 1; fi
}

_test_all_arch_full_upgrade() {
    _all_core_setup
    source "$_ALL_CORE_APP/adapters/output/pkg_arch.sh"
    proot_setup_sudo_path() { :; }
    local args=''
    proot_exec() { args="$*"; }
    proot_pkg_update
    assert_eq 'sudo pacman -Syu --noconfirm' "$args"
}

_all_desktop_setup() {
    _all_core_setup
    source "$_ALL_CORE_APP/domain/desktop.sh"
    printf 'original menu\n' > "$PREFIX/share/applications/demo.desktop"
    printf 'original shortcut\n' > "$HOME/Desktop/demo.desktop"
}

_all_desktop_original() {
    assert_eq 'original menu' "$(cat "$PREFIX/share/applications/demo.desktop")"
    assert_eq 'original shortcut' "$(cat "$HOME/Desktop/demo.desktop")"
    [ -z "$(find "$PREFIX/share/applications" "$HOME/Desktop" -name '.desktop-register.*' -print)" ]
}

_test_all_desktop_staging_failure() {
    _all_desktop_setup
    mktemp() {
        case "${@: -1}" in "$HOME/Desktop/"*) return 42 ;; esac
        command mktemp "$@"
    }
    if desktop_register demo Demo demo demo 'Utility;'; then return 1; fi
    unset -f mktemp
    _all_desktop_original
}

_test_all_desktop_write_failure() {
    _all_desktop_setup
    printf() { return 42; }
    if desktop_register demo Demo demo demo 'Utility;'; then return 1; fi
    unset -f printf
    _all_desktop_original
}

_test_all_desktop_copy_failure() {
    _all_desktop_setup
    cp() { return 42; }
    if desktop_register demo Demo demo demo 'Utility;'; then return 1; fi
    unset -f cp
    _all_desktop_original
}

_test_all_desktop_chmod_failure() {
    _all_desktop_setup
    chmod() { return 42; }
    if desktop_register demo Demo demo demo 'Utility;'; then return 1; fi
    unset -f chmod
    _all_desktop_original
}

_test_all_desktop_publication_failure() {
    _all_desktop_setup
    mv() {
        case "${@: -2:1}" in */shortcut) return 42 ;; esac
        command mv "$@"
    }
    if desktop_register demo Demo demo demo 'Utility;'; then return 1; fi
    unset -f mv
    _all_desktop_original
}

_test_all_desktop_success() {
    _all_desktop_setup
    desktop_register demo Demo 'demo %f' demo 'Utility;' 'MimeType=text/plain;'
    assert_file_contains "$PREFIX/share/applications/demo.desktop" '^Exec=demo %f$'
    assert_file_contains "$HOME/Desktop/demo.desktop" '^MimeType=text/plain;$'
    [ -x "$HOME/Desktop/demo.desktop" ]
}

_all_codex_setup() {
    _all_core_setup
    source "$_ALL_CORE_APP/domain/installers/codex.sh"
    termux_pkg_install() { :; }
    termux_pkg_is_installed() { return 1; }
    fetch_verified() {
        if [[ "$1" == *codex-code-mode-host* ]] && [ "${_ALL_HELPER_FAIL:-0}" = 1 ]; then return 42; fi
        printf '%s\n' "$1" > "$2"
    }
    tar() {
        case "$4" in
            "$CODEX_TARBALL_MEMBER") printf '#!%s\nprintf "codex-cli %s\\n"\n' "$BASH" "$CODEX_PIN_VERSION" ;;
            "$CODEX_CMH_TARBALL_MEMBER") printf '#!%s\n# helper %s\nexit 0\n' "$BASH" "$CODEX_PIN_VERSION" ;;
            *) return 99 ;;
        esac
    }
    app_install_codex >/dev/null
    _ALL_OLD_VERSION="$CODEX_PIN_VERSION"
    _ALL_OLD_MAIN=$(sha256sum "$CODEX_REAL_BIN")
    _ALL_OLD_HELPER=$(sha256sum "$CODEX_CMH_BIN")
    _ALL_OLD_MANIFEST=$(cat "$CODEX_INSTALL_MANIFEST")
}

_all_codex_next_pin() {
    CODEX_PIN_VERSION=0.160.0
    CODEX_TARBALL_SHA256[$CODEX_PIN_VERSION]="${CODEX_TARBALL_SHA256[$_ALL_OLD_VERSION]}"
    CODEX_CMH_SHA256[$CODEX_PIN_VERSION]="${CODEX_CMH_SHA256[$_ALL_OLD_VERSION]}"
}

_all_codex_original() {
    assert_eq "$_ALL_OLD_MAIN" "$(sha256sum "$CODEX_REAL_BIN")"
    assert_eq "$_ALL_OLD_HELPER" "$(sha256sum "$CODEX_CMH_BIN")"
    assert_eq "$_ALL_OLD_MANIFEST" "$(cat "$CODEX_INSTALL_MANIFEST")"
    [ -z "$(find "$CODEX_PREFIX" -name '.codex-*' -print)" ]
}

_test_all_codex_helper_failure_and_retry() {
    _all_codex_setup
    _all_codex_next_pin
    _ALL_HELPER_FAIL=1
    if app_upgrade_codex >/dev/null; then return 1; fi
    _all_codex_original
    _ALL_HELPER_FAIL=0
    app_upgrade_codex >/dev/null
    app_verify_codex
    local rc=0
    app_upgrade_codex >/dev/null || rc=$?
    assert_eq 2 "$rc"
}

_all_codex_failed_publication() {
    local fail_file="$1"
    _all_codex_setup
    _all_codex_next_pin
    mv() {
        local src="${@: -2:1}" dst="${@: -1}"
        if [ "$dst" = "$CODEX_PREFIX/$fail_file" ] && [ "${src##*/}" = "$fail_file" ]; then return 42; fi
        command mv "$@"
    }
    if _codex_download "$CODEX_PIN_VERSION"; then return 1; fi
    unset -f mv
    _all_codex_original
}

_test_all_codex_helper_publication_failure() { _all_codex_failed_publication codex-code-mode-host; }
_test_all_codex_manifest_publication_failure() { _all_codex_failed_publication installation; }

_test_all_codex_corrupted_helper_is_repaired() {
    _all_codex_setup
    printf 'stale helper\n' > "$CODEX_CMH_BIN"
    if app_verify_codex; then return 1; fi
    app_install_codex >/dev/null
    app_verify_codex
    rm "$CODEX_INSTALL_MANIFEST"
    if app_verify_codex; then return 1; fi
    app_install_codex >/dev/null
    app_verify_codex
    rm "$CODEX_CMH_BIN"
    if app_verify_codex; then return 1; fi
    app_install_codex >/dev/null
    app_verify_codex
}

_test_all_codex_unknown_helper_hash_is_rejected() {
    _all_codex_setup
    CODEX_PIN_VERSION=0.160.0
    CODEX_TARBALL_SHA256[$CODEX_PIN_VERSION]="${CODEX_TARBALL_SHA256[$_ALL_OLD_VERSION]}"
    fetch_verified() { echo 'unverified download must not start' >&2; return 99; }
    if _codex_download "$CODEX_PIN_VERSION"; then return 1; fi
    _all_codex_original
}

_all_miniforge_setup() {
    _all_core_setup
    export PROOT_DISTRO=ubuntu PROOT_USER=testuser PROOT_ROOTFS_BASE="$_ALL_CORE_SB/rootfs"
    export ALL_CONTAINER_HOME="$PROOT_ROOTFS_BASE/containers/ubuntu/rootfs/home/testuser"
    export ALL_INSTALLER_FAIL=0 ALL_FETCH_FAIL=0 ALL_BASH="$BASH"
    mkdir -p "$ALL_CONTAINER_HOME"
    source "$_ALL_CORE_APP/lib/proot_path.sh"
    source "$_ALL_CORE_APP/lib/fetch.sh"
    source "$_ALL_CORE_APP/domain/apps.sh"
    source "$_ALL_CORE_APP/domain/installers/miniforge.sh"
    proot_pkg_update() { :; }
    proot_pkg_install() { :; }
    proot_pkg_install_python_pip() { :; }
    proot_exec() { HOME="$ALL_CONTAINER_HOME" "$@"; }
    fetch_verified() {
        [ "$ALL_FETCH_FAIL" = 0 ] || return 43
        cat > "$2" <<'INSTALLER'
set -eu
prefix=$3
[ "$1" = -b ] && [ "$2" = -p ] && [ ! -e "$prefix" ] || exit 61
mkdir -p "$prefix/bin" "$prefix/conda-meta"
if [ "$ALL_INSTALLER_FAIL" = 1 ]; then printf partial > "$prefix/partial"; exit 42; fi
for name in conda python; do
    printf '#!%s\nprintf "%s fixture\\n"\n' "$ALL_BASH" "$name" > "$prefix/bin/$name"
    chmod +x "$prefix/bin/$name"
done
printf completed > "$prefix/conda-meta/history"
INSTALLER
    }
}

_test_all_miniforge_incomplete_prefix_recovers() {
    _all_miniforge_setup
    mkdir -p "$ALL_CONTAINER_HOME/miniforge3"
    printf previous > "$ALL_CONTAINER_HOME/miniforge3/marker"
    if app_is_installed_miniforge; then return 1; fi
    app_install_miniforge
    app_is_installed_miniforge
    [ ! -e "$ALL_CONTAINER_HOME/miniforge3/marker" ]
    local backup
    backup=$(find "$ALL_CONTAINER_HOME" -path '*/.miniforge3-backup.*/marker' -print)
    assert_eq previous "$(cat "$backup")"
    # A healthy installation must not run package/download operations again.
    proot_pkg_update() { return 99; }
    fetch_verified() { return 99; }
    app_install_miniforge
}

_test_all_miniforge_failed_install_preserves_prefix() {
    _all_miniforge_setup
    mkdir -p "$ALL_CONTAINER_HOME/miniforge3"
    printf previous > "$ALL_CONTAINER_HOME/miniforge3/marker"
    ALL_INSTALLER_FAIL=1
    if app_install_miniforge; then return 1; fi
    assert_eq previous "$(cat "$ALL_CONTAINER_HOME/miniforge3/marker")"
    [ ! -e "$ALL_CONTAINER_HOME/miniforge3/partial" ]
    ALL_INSTALLER_FAIL=0
    app_install_miniforge
    app_is_installed_miniforge
}

_test_all_miniforge_failed_download_preserves_prefix() {
    _all_miniforge_setup
    mkdir -p "$ALL_CONTAINER_HOME/miniforge3"
    printf previous > "$ALL_CONTAINER_HOME/miniforge3/marker"
    ALL_FETCH_FAIL=1
    if app_install_miniforge; then return 1; fi
    assert_eq previous "$(cat "$ALL_CONTAINER_HOME/miniforge3/marker")"
}

describe 'Core review fixes — package state and safe publication'
it 'Termux checks exact installed state without a SIGPIPE-prone listing' _test_all_termux_exact_state
it 'Ubuntu rejects removed, broken and missing packages' _test_all_ubuntu_exact_state
it 'Arch refresh also upgrades installed packages' _test_all_arch_full_upgrade
it 'failure to stage a Desktop shortcut preserves both old launchers' _test_all_desktop_staging_failure
it 'launcher write failure preserves both old launchers' _test_all_desktop_write_failure
it 'launcher copy failure preserves both old launchers' _test_all_desktop_copy_failure
it 'launcher chmod failure preserves both old launchers' _test_all_desktop_chmod_failure
it 'second launcher publication failure restores both old launchers' _test_all_desktop_publication_failure
it 'launcher publication succeeds despite unavailable trust metadata' _test_all_desktop_success
it 'Codex helper download failure preserves the pair and retry repairs it' _test_all_codex_helper_failure_and_retry
it 'Codex helper publication failure restores binaries and manifest' _test_all_codex_helper_publication_failure
it 'Codex manifest publication failure restores binaries and manifest' _test_all_codex_manifest_publication_failure
it 'Codex repairs executable stale helpers and missing helpers' _test_all_codex_corrupted_helper_is_repaired
it 'Codex refuses helper downloads without a pinned hash' _test_all_codex_unknown_helper_hash_is_rejected
it 'Miniforge repairs partial prefixes and skips healthy installs' _test_all_miniforge_incomplete_prefix_recovers
it 'Miniforge restores a partial prefix after installer failure and allows retry' _test_all_miniforge_failed_install_preserves_prefix
it 'Miniforge preserves an existing prefix when downloading fails' _test_all_miniforge_failed_download_preserves_prefix
print_results
