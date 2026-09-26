#!/usr/bin/env bash
# Exercise the real CLI and adapters; isolate package/download commands in PATH.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$TEST_DIR/.." && pwd)"
source "$TEST_DIR/framework.sh"

_cli_setup() {
    local sb="$1" name
    export HOME="$sb/home" PREFIX="$sb/usr" TMPDIR="$sb/tmp"
    export TEST_TRACE="$sb/commands.log"
    export PATH="$sb/bin:/usr/bin:/bin"
    unset PROOT_DISTRO PROOT_USER PROOT_ROOTFS_BASE KOREAN_LOCALE_ZIP UI
    unset DISPLAY_SERVER WAYLAND_DISPLAY ANLAND XFCE4_SESSION_COMPOSITOR XDG_CURRENT_DESKTOP
    unset TEST_SHA TEST_REMOVE_RC TEST_CLANG_RC TEST_NPM_INSTALLED
    mkdir -p "$HOME/.config/termux-xfce" "$HOME/Desktop" "$sb/bin" "$TMPDIR" \
        "$PREFIX/lib" "$PREFIX/etc" "$PREFIX/bin" "$PREFIX/share/applications"
    touch "$PREFIX/etc/bash.bashrc" "$HOME/.zshrc" "$TEST_TRACE"
    cat > "$sb/bin/stub" <<'STUB'
#!/usr/bin/env bash
set -eu
name="${0##*/}"
printf '%s %s\n' "$name" "$*" >> "$TEST_TRACE"
case "$name" in
    pkg)
        case "$1" in
            list-installed) exit 0 ;;
            uninstall) exit "${TEST_REMOVE_RC:-0}" ;;
            install) exit 0 ;;
        esac ;;
    dpkg)
        case "$1" in
            -i) exit 0 ;;
            -r) exit "${TEST_REMOVE_RC:-0}" ;;
        esac ;;
    wget|curl)
        while [ "$#" -gt 0 ]; do
            case "$1" in
                -O|-o) printf 'download fixture\n' > "$2"; exit 0 ;;
            esac
            shift
        done ;;
    sha256sum) printf '%s  %s\n' "$TEST_SHA" "$1"; exit 0 ;;
    tar)
        while [ "$#" -gt 0 ]; do
            if [ "$1" = -C ]; then
                printf 'native binary fixture\n' > "$2/claude"; exit 0
            fi
            shift
        done ;;
    clang)
        [ "${TEST_CLANG_RC:-0}" = 0 ] || exit "$TEST_CLANG_RC"
        dest=""
        for arg in "$@"; do
            case "$arg" in *.c) [ -f "$arg" ] || exit 1 ;; esac
        done
        while [ "$#" -gt 0 ]; do
            if [ "$1" = -o ]; then dest="$2"; break; fi
            shift
        done
        printf 'shared library fixture\n' > "$dest"; exit 0 ;;
    npm)
        if [ "$1" = ls ]; then
            [ "${TEST_NPM_INSTALLED:-0}" = 1 ] || exit 1
            echo '@anthropic-ai/claude-code'
            exit 0
        fi
        exit "${TEST_REMOVE_RC:-0}" ;;
    proot-distro|glib-compile-schemas|gio) exit 0 ;;
esac
echo "Unexpected fixture command: $name $*" >&2
exit 1
STUB
    chmod +x "$sb/bin/stub"
    for name in pkg dpkg wget curl sha256sum tar clang npm proot-distro glib-compile-schemas gio; do
        ln -s stub "$sb/bin/$name"
    done
}

_cli() { bash "$APP_DIR/app-install.sh" "$@"; }
_cli_saved_config() {
    printf 'PROOT_DISTRO=ubuntu\nPROOT_USER=saveduser\n' > "$HOME/.config/termux-xfce/config"
}

describe 'CLI — native downloads'
_test_cli_native_nimf() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"
    export PROOT_DISTRO=""
    source "$APP_DIR/domain/installers/nimf.sh"
    export TEST_SHA="$_NIMF_DEB_SHA256"
    _cli install nimf
    assert_file_contains "$TEST_TRACE" 'sha256sum .*nimf'
    assert_file_contains "$TEST_TRACE" 'dpkg -i --force-overwrite'
    assert_file_exists "$HOME/.config/autostart/nimf.desktop"
    cleanup_sandbox "$sb"
}
it 'native-only nimf downloads, verifies, and installs through the CLI' _test_cli_native_nimf

_test_cli_native_claude() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"
    export PROOT_DISTRO=""
    source "$APP_DIR/domain/installers/claude_code.sh"
    export TEST_SHA="${CLAUDE_CODE_TARBALL_SHA256[$CLAUDE_CODE_PIN_VERSION]}"
    _cli install claude_code
    assert_file_contains "$TEST_TRACE" 'sha256sum .*native.tgz'
    [ -x "$PREFIX/bin/claude" ]
    [ -x "$PREFIX/share/claude-code/claude" ]
    cleanup_sandbox "$sb"
}
it 'native-only Claude Code verifies and extracts through the CLI' _test_cli_native_claude

describe 'CLI — explicit environment takes priority over saved config'
_test_cli_explicit_target() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"; _cli_saved_config
    PROOT_DISTRO=archlinux PROOT_USER=chosen _cli status onepassword
    assert_file_contains "$TEST_TRACE" 'login archlinux --user chosen'
    cleanup_sandbox "$sb"
}
it 'explicit distro and user override both saved values' _test_cli_explicit_target

_test_cli_saved_target() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"; _cli_saved_config
    _cli status onepassword
    assert_file_contains "$TEST_TRACE" 'login ubuntu --user saveduser'
    cleanup_sandbox "$sb"
}
it 'unset environment uses the saved distro and user' _test_cli_saved_target

_test_cli_detect_user_for_new_distro() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"; _cli_saved_config
    mkdir -p "$PREFIX/var/lib/proot-distro/installed-rootfs/archlinux/home/archuser"
    PROOT_DISTRO=archlinux _cli status onepassword
    assert_file_contains "$TEST_TRACE" 'login archlinux --user archuser'
    cleanup_sandbox "$sb"
}
it 'switching distro detects its user instead of retaining the saved distro user' _test_cli_detect_user_for_new_distro

_test_cli_native_override() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"; _cli_saved_config
    PROOT_DISTRO="" _cli status onepassword
    if grep -q '^proot-distro ' "$TEST_TRACE"; then return 1; fi
    cleanup_sandbox "$sb"
}
it 'explicit empty distro preserves native-only mode' _test_cli_native_override

describe 'CLI — removal failures'
_test_cli_failed_remove_keeps_launchers() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"
    touch "$PREFIX/share/applications/vlc.desktop" "$HOME/Desktop/vlc.desktop"
    export TEST_REMOVE_RC=42
    if _cli remove vlc > "$sb/output" 2>&1; then return 1; fi
    assert_file_contains "$sb/output" '\[ERROR\] vlc'
    assert_file_exists "$PREFIX/share/applications/vlc.desktop"
    assert_file_exists "$HOME/Desktop/vlc.desktop"
    cleanup_sandbox "$sb"
}
it 'failed package removal returns failure and retains both VLC launchers' _test_cli_failed_remove_keeps_launchers

_test_cli_successful_remove() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"
    touch "$PREFIX/share/applications/vlc.desktop" "$HOME/Desktop/vlc.desktop"
    _cli remove vlc
    [ ! -e "$PREFIX/share/applications/vlc.desktop" ]
    [ ! -e "$HOME/Desktop/vlc.desktop" ]
    cleanup_sandbox "$sb"
}
it 'successful package removal cleans up VLC launchers' _test_cli_successful_remove

_test_cli_failed_npm_remove() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"
    mkdir -p "$PREFIX/share/claude-code"
    touch "$PREFIX/share/claude-code/claude" "$PREFIX/bin/claude"
    chmod +x "$PREFIX/share/claude-code/claude" "$PREFIX/bin/claude"
    export TEST_REMOVE_RC=42 TEST_NPM_INSTALLED=1
    if _cli remove claude_code; then return 1; fi
    assert_file_exists "$PREFIX/bin/claude"
    assert_file_exists "$PREFIX/share/claude-code/claude"
    cleanup_sandbox "$sb"
}
it 'failed npm removal preserves the Claude wrapper and binary' _test_cli_failed_npm_remove

describe 'CLI — parent locale integration'
_cli_locale_zip() {
    export KOREAN_LOCALE_ZIP="$TMPDIR/locale.zip"
    python3 - "$KOREAN_LOCALE_ZIP" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as archive:
    archive.writestr("ko/LC_MESSAGES/gtk30.mo", b"catalog fixture")
PY
}
_test_cli_locale_requires_zip() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"
    if _cli install korean_locale > "$sb/output" 2>&1; then return 1; fi
    assert_file_contains "$sb/output" 'KOREAN_LOCALE_ZIP'
    [ ! -e "$PREFIX/lib/force_gettext.so" ]
    cleanup_sandbox "$sb"
}
_test_cli_locale_builds() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"; _cli_locale_zip
    # A failed older installation may have left an empty output file.
    touch "$PREFIX/lib/force_gettext.so"
    _cli install korean_locale
    [ -s "$PREFIX/lib/force_gettext.so" ]
    [ -x "$HOME/bin/startxfce4-ko" ]
    assert_file_exists "$PREFIX/share/locale/ko/LC_MESSAGES/gtk30.mo"
    assert_file_contains "$PREFIX/etc/bash.bashrc" 'force_gettext.so'
    assert_file_contains "$TEST_TRACE" '/assets/force_gettext.c'
    cleanup_sandbox "$sb"
}
_test_cli_locale_build_fails() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"; _cli_locale_zip
    export TEST_CLANG_RC=42
    if _cli install korean_locale > "$sb/output" 2>&1; then return 1; fi
    [ ! -e "$PREFIX/lib/force_gettext.so" ]
    [ ! -e "$HOME/bin/startxfce4-ko" ]
    assert_file_contains "$sb/output" '\[ERROR\]'
    cleanup_sandbox "$sb"
}
if [ -f "$APP_DIR/../domain/locale_ko.sh" ]; then
    it 'missing catalog ZIP makes locale installation fail' _test_cli_locale_requires_zip
    it 'valid ZIP loads parent adapters and builds from parent assets' _test_cli_locale_builds
    it 'compiler failure propagates without leaving a library or launcher' _test_cli_locale_build_fails
else
    skip 'parent locale integration requires the Termux_XFCE checkout'
fi

print_results
