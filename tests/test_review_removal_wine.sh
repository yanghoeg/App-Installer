#!/data/data/com.termux/files/usr/bin/bash
# Regression checks for review candidates 10, 11, 13, 15, 20, 21, 22 and 24.
# Package commands and container execution are mocked; all writes use a sandbox.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$TEST_DIR/.." && pwd)"
source "$TEST_DIR/framework.sh"
_REVIEW_BASH="${BASH:-$(command -v bash)}"

_review_setup() {
    local sb
    sb=$(make_sandbox)
    _REVIEW_SANDBOX="$sb"
    trap 'cleanup_sandbox "$_REVIEW_SANDBOX"' EXIT
    export HOME="$sb/home" PREFIX="$sb/usr" TMPDIR="$sb/tmp"
    export PROOT_DISTRO=archlinux PROOT_USER=testuser PROOT_ROOTFS_BASE="$sb/rootfs"
    export PATH="$sb/mock-bin:$PATH"
    mkdir -p "$HOME/Desktop" "$PREFIX/bin" "$PREFIX/share/applications" "$TMPDIR" \
        "$sb/mock-bin" "$PROOT_ROOTFS_BASE/installed-rootfs/$PROOT_DISTRO"
    # exec ignores exported shell functions. Executable PATH fixtures also stop
    # any accidentally unmocked branch before it reaches the real package tools.
    {
        printf '#!%s\n' "$_REVIEW_BASH"
        cat <<'STUB'
set -eu
case "${0##*/}" in
    pacman)
        if [ "$1" = -Qq ]; then
            printf '%s\n' "${REVIEW_INSTALLED:-}"
            exit "${REVIEW_QUERY_RC:-99}"
        fi
        printf '%s\n' "$*" >> "$REVIEW_TRACE"
        exit "${REVIEW_REMOVE_RC:-99}" ;;
    dpkg-query)
        printf '%s\n' "${REVIEW_INSTALLED:-}"
        exit "${REVIEW_QUERY_RC:-99}" ;;
    apt)
        printf '%s\n' "$*" >> "$REVIEW_TRACE"
        exit "${REVIEW_REMOVE_RC:-99}" ;;
    *) echo "unmocked package/container command: ${0##*/} $*" >&2; exit 99 ;;
esac
STUB
    } > "$sb/mock-bin/stub"
    chmod +x "$sb/mock-bin/stub"
    local tool
    for tool in pacman dpkg-query apt apt-get pkg sudo proot-distro wget curl git \
        wine wineboot wineserver grun prun termux-wake-lock; do
        ln -s stub "$sb/mock-bin/$tool"
    done
    source "$APP_DIR/lib/proot_path.sh"
    source "$APP_DIR/lib/wine_backend.sh"
    source "$APP_DIR/domain/apps.sh"
    source "$APP_DIR/domain/desktop.sh"
    source "$APP_DIR/adapters/output/pkg_termux.sh"
    local id
    for id in tor_browser dbeaver burpsuite thorium sasm teams nautilus libreoffice wine wayvnc; do
        source "$APP_DIR/domain/installers/$id.sh"
    done
}

_test_native_launcher_removal() {
    _review_setup
    PROOT_DISTRO=''
    proot_exec() { echo 'unexpected container execution' >&2; return 42; }
    proot_pkg_remove() { return 42; }
    proot_pkg_purge() { return 42; }
    proot_pkg_remove_libreoffice() { return 42; }
    proot_pkg_autoremove() { return 42; }
    local pair id launcher
    for pair in tor_browser:tor dbeaver:dbeaver burpsuite:burpsuite thorium:thorium-browser \
        sasm:sasm teams:teams nautilus:nautilus libreoffice:libreoffice-writer; do
        id=${pair%%:*}; launcher=${pair#*:}
        touch "$PREFIX/share/applications/$launcher.desktop" "$HOME/Desktop/$launcher.desktop"
        "app_remove_$id"
        "app_remove_$id"
        [ ! -e "$PREFIX/share/applications/$launcher.desktop" ]
        [ ! -e "$HOME/Desktop/$launcher.desktop" ]
    done
}

_test_failed_container_removal_keeps_launchers() {
    _review_setup
    proot_exec() { return 42; }
    proot_pkg_remove() { return 42; }
    proot_pkg_purge() { return 42; }
    proot_pkg_remove_libreoffice() { return 42; }
    local pair id launcher
    for pair in tor_browser:tor dbeaver:dbeaver burpsuite:burpsuite thorium:thorium-browser \
        sasm:sasm teams:teams nautilus:nautilus libreoffice:libreoffice-writer; do
        id=${pair%%:*}; launcher=${pair#*:}
        touch "$PREFIX/share/applications/$launcher.desktop"
        if "app_remove_$id"; then return 1; fi
        assert_file_exists "$PREFIX/share/applications/$launcher.desktop"
    done
}

# Execute only the generated package-removal script using PATH fixtures.
# No real proot, sudo, pacman, dpkg or apt is invoked.
_mock_removal_exec() {
    [ "$1" = sudo ] && [ "$2" = bash ] && [ "$3" = -c ]
    shift 3
    bash -c "$@"
}

_test_arch_removal_filters_missing_and_propagates_errors() {
    _review_setup
    source "$APP_DIR/adapters/output/pkg_arch.sh"
    proot_exec() { _mock_removal_exec "$@"; }
    export REVIEW_QUERY_RC=0 REVIEW_REMOVE_RC=0 REVIEW_INSTALLED=$'teams-for-linux\nnautilus-extra'
    export REVIEW_TRACE="$HOME/packages.log"
    proot_pkg_remove missing nautilus teams-for-linux
    assert_eq '-Rns --noconfirm -- teams-for-linux' "$(cat "$REVIEW_TRACE")"
    : > "$REVIEW_TRACE"
    REVIEW_INSTALLED=''
    proot_pkg_remove teams-for-linux
    proot_pkg_purge teams-for-linux
    [ ! -s "$REVIEW_TRACE" ]
    REVIEW_QUERY_RC=42
    if proot_pkg_remove teams-for-linux; then return 1; fi
    REVIEW_QUERY_RC=0 REVIEW_INSTALLED=teams-for-linux REVIEW_REMOVE_RC=42
    if proot_pkg_remove teams-for-linux; then return 1; fi
}

_test_ubuntu_removal_filters_missing_and_keeps_purge_semantics() {
    _review_setup
    source "$APP_DIR/adapters/output/pkg_ubuntu.sh"
    proot_exec() { _mock_removal_exec "$@"; }
    export REVIEW_QUERY_RC=0 REVIEW_REMOVE_RC=0
    export REVIEW_INSTALLED=$'nautilus:arm64\tinstalled\nteams-for-linux\tconfig-files\ngone\tnot-installed'
    export REVIEW_TRACE="$HOME/packages.log"
    proot_pkg_remove missing nautilus teams-for-linux gone
    assert_eq 'remove -y -- nautilus' "$(cat "$REVIEW_TRACE")"
    : > "$REVIEW_TRACE"
    proot_pkg_purge missing teams-for-linux gone
    assert_eq 'purge -y -- teams-for-linux' "$(cat "$REVIEW_TRACE")"
    : > "$REVIEW_TRACE"
    REVIEW_INSTALLED=''
    proot_pkg_remove nautilus
    proot_pkg_purge nautilus
    [ ! -s "$REVIEW_TRACE" ]
    REVIEW_QUERY_RC=42
    if proot_pkg_remove nautilus; then return 1; fi
    REVIEW_QUERY_RC=0 REVIEW_INSTALLED=$'nautilus\tinstalled' REVIEW_REMOVE_RC=42
    if proot_pkg_remove nautilus; then return 1; fi
}

_test_box64_installs_python_before_build() {
    _review_setup
    local distro captured='' built=0
    for distro in arch ubuntu; do
        source "$APP_DIR/adapters/output/pkg_$distro.sh"
        proot_pkg_install() { captured=" $* "; }
        proot_exec() { built=$((built + 1)); }
        proot_pkg_install_box64
        case "$distro:$captured" in
            arch:*' python '*) ;; ubuntu:*' python3 '*) ;; *) return 1 ;;
        esac
    done
    assert_eq 2 "$built"
    proot_pkg_install() { return 42; }
    if proot_pkg_install_box64; then return 1; fi
    assert_eq 2 "$built"
}

_test_termux_install_keeps_modified_conffiles() {
    _review_setup
    local -a args=()
    pkg() { args=("$@"); }
    termux_pkg_install firefox
    assert_eq install "${args[0]}"
    assert_eq '-y' "${args[1]}"
    assert_eq '-o' "${args[2]}"
    assert_eq 'Dpkg::Options::=--force-confold' "${args[3]}"
    assert_eq firefox "${args[4]}"
}

_test_wine_ignores_host_dispatcher_when_installing() {
    _review_setup
    local updated=0 built=0 downloaded=0 checks=0
    # The old `which wine` call succeeds due to a host dispatcher; the new probe
    # must constrain PATH and require the actual container tarball.
    proot_exec() {
        if [ "${1:-}" = which ]; then return 0; fi
        [ "$1" = env ] && [ "$2" = PATH=/usr/local/bin:/usr/bin:/bin ]
        checks=$((checks + 1))
        case "${5:-}" in
            *'test -x /opt/wine-staging/bin/wine'*) return 1 ;;
            'command -v box64') return 0 ;;
            *) return 42 ;;
        esac
    }
    proot_pkg_update() { updated=$((updated + 1)); }
    proot_pkg_install_box64() { built=$((built + 1)); }
    _wine_install_tarball_proot() { downloaded=$((downloaded + 1)); }
    proot_pkg_install_wine_mesa() { :; }
    _wine_install_winetricks_proot() { :; }
    _wine_init_prefix_proot() { :; }
    _wine_create_launchers() { :; }
    app_install_wine >/dev/null
    assert_eq 1 "$updated"
    assert_eq 1 "$built"
    assert_eq 1 "$downloaded"
    assert_eq 2 "$checks"
}

_test_wine_wrapper_uses_container_binary() {
    _review_setup
    wine_wire_frontend() { :; }
    wine_backend_set_default() { :; }
    gio() { :; }
    SCRIPT_DIR="$APP_DIR"
    _wine_create_launchers
    assert_file_contains "$_WINE_BIN" 'exec /opt/wine-staging/bin/wine'
    if command grep -q 'exec wine ' "$_WINE_BIN"; then return 1; fi
}

_test_wine_exec_skips_login_hooks_and_preserves_arguments() {
    _review_setup
    source "$APP_DIR/adapters/output/pkg_proot_base.sh"
    local -a captured=()
    proot_exec() { captured=("$@"); }
    proot_exec_wine printf '%s\n' 'space value' '%literal'
    assert_eq bash "${captured[0]}"
    assert_eq --noprofile "${captured[1]}"
    assert_eq --norc "${captured[2]}"
    assert_eq -c "${captured[3]}"
    [[ "${captured[4]}" == *'/etc/profile.d/gpu-accel.sh'* ]]
    [[ "${captured[4]}" != *'--login'* ]]
    [[ "${captured[4]}" != *'termux-xfce-locale'* ]]
    # Replace the fixed GPU-profile path for this host-only execution. The command
    # handoff is executed as emitted, including GPU loading, exec and argv.
    local snippet="${captured[4]}"
    printf 'export REVIEW_GPU=enabled\nprintf sourced > "$HOME/gpu-sourced"\n' > "$HOME/gpu-accel.sh"
    snippet="${snippet//\/etc\/profile.d\/gpu-accel.sh/$HOME/gpu-accel.sh}"
    assert_eq $'space value\n%literal' "$(bash --noprofile --norc -c "$snippet" "${captured[@]:5}")"
    assert_eq sourced "$(cat "$HOME/gpu-sourced")"
    assert_eq :0.0 "$(env -u DISPLAY bash --noprofile --norc -c "$snippet" wine-exec bash --noprofile --norc -c 'printf %s "$DISPLAY"')"
    assert_eq :0.0 "$(DISPLAY= bash --noprofile --norc -c "$snippet" wine-exec bash --noprofile --norc -c 'printf %s "$DISPLAY"')"
    assert_eq :91 "$(DISPLAY=:91 bash --noprofile --norc -c "$snippet" wine-exec bash --noprofile --norc -c 'printf %s "$DISPLAY"')"
    local init_calls=0
    proot_exec_wine() { init_calls=$((init_calls + 1)); [[ "$*" != *'wineserver -p'* ]]; }
    _wine_init_prefix_proot >/dev/null
    assert_eq 1 "$init_calls"
}

_test_wine_removal_deletes_source_box64_without_package_entry() {
    _review_setup
    wine_backend_record_context proot "$PROOT_DISTRO" "$PROOT_USER" "$PROOT_ROOTFS_BASE"
    proot_pkg_is_installed() { return 1; }
    proot_pkg_remove() { echo 'unexpected package removal' >&2; return 42; }
    local snippet=''
    proot_exec() {
        [ "$1" = sudo ] && [ "$2" = bash ] && [ "$3" = -c ]
        printf '%s' "$4" > "$HOME/proot-removal.sh"
    }
    touch "$_WINE_BIN" "$_WINE_DESKTOP"
    app_remove_wine
    snippet=$(cat "$HOME/proot-removal.sh")
    [[ "$snippet" == *'rm -f /usr/local/bin/box64'* ]]
    # Execute the cleanup with every container absolute path mapped into sandbox.
    snippet="${snippet//\/usr\/local\/bin/$PREFIX/bin}"
    snippet="${snippet//\/opt\/wine-staging/$HOME/wine-staging}"
    touch "$PREFIX/bin/box64" "$PREFIX/bin/wine"
    mkdir -p "$HOME/wine-staging"
    bash -c "$snippet"
    [ ! -e "$PREFIX/bin/box64" ]
    [ ! -e "$PREFIX/bin/wine" ]
    [ ! -e "$HOME/wine-staging" ]
    [ ! -e "$_WINE_DESKTOP" ]
}

_test_wayvnc_requires_supported_live_session() {
    _review_setup
    local desktop
    unset WAYLAND_DISPLAY ANLAND XDG_CURRENT_DESKTOP XFCE4_SESSION_COMPOSITOR
    if _wayvnc_check_compositor 2>/dev/null; then return 1; fi
    WAYLAND_DISPLAY=wayland-0
    if _wayvnc_check_compositor 2>/dev/null; then return 1; fi
    for desktop in KDE GNOME XFCE; do
        XDG_CURRENT_DESKTOP="$desktop"
        if _wayvnc_check_compositor 2>/dev/null; then return 1; fi
    done
    XDG_CURRENT_DESKTOP=sway
    _wayvnc_check_compositor
    XDG_CURRENT_DESKTOP='Sway:custom'
    _wayvnc_check_compositor
    ANLAND=1
    if _wayvnc_check_compositor 2>/dev/null; then return 1; fi
}

_test_retired_app_visibility_depends_on_existing_install() {
    _review_setup
    if app_can_install tor_browser; then return 1; fi
    if app_is_visible tor_browser; then return 1; fi
    touch "$PREFIX/share/applications/tor.desktop"
    app_is_visible tor_browser
    app_can_install notion
}

describe 'review — idempotent removal and failure preservation'
it 'native-only leftovers can be removed repeatedly for all eight proot apps' _test_native_launcher_removal
it 'real container errors preserve all eight app launchers' _test_failed_container_removal_keeps_launchers
it 'Arch filters absent packages and propagates query/removal failures' _test_arch_removal_filters_missing_and_propagates_errors
it 'Ubuntu handles absent packages, multiarch names and config-only purge' _test_ubuntu_removal_filters_missing_and_keeps_purge_semantics
describe 'review — build and package dependencies'
it 'both Box64 adapters install Python and stop before build on failure' _test_box64_installs_python_before_build
it 'Termux package installs preserve modified conffiles without prompting' _test_termux_install_keeps_modified_conffiles
describe 'review — Wine container isolation'
it 'a host Wine dispatcher cannot suppress container installation' _test_wine_ignores_host_dispatcher_when_installing
it 'generated proot wrapper invokes the actual container Wine path' _test_wine_wrapper_uses_container_binary
it 'Wine execution skips login IME hooks, preserves argv and avoids a doomed server' _test_wine_exec_skips_login_hooks_and_preserves_arguments
it 'source-installed Box64 is cleaned up without a package database entry' _test_wine_removal_deletes_source_box64_without_package_entry
describe 'review — session support and retired app visibility'
it 'wayvnc rejects X11, unknown/KWin sockets and accepts an external Sway session' _test_wayvnc_requires_supported_live_session
it 'retired apps are shown only while an existing install remains' _test_retired_app_visibility_depends_on_existing_install
print_results
