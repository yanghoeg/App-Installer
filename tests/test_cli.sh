#!/data/data/com.termux/files/usr/bin/bash
# Exercise the real CLI and adapters; isolate package/download commands in PATH.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$TEST_DIR/.." && pwd)"
source "$TEST_DIR/framework.sh"

# Termux 의 /usr/bin:/bin 에서 빠진 것은 bash 뿐이다(나머지 기본 유틸은 Android
# toybox 가 제공). PATH 에 $PREFIX/bin 을 통째로 넣으면 기기에 실제 설치된 앱이
# 보여 app_is_installed_* 격리가 깨지므로, bash 하나만 샌드박스에 넣는다.
_CLI_BASH="${BASH:-$(command -v bash)}"
# 픽스처 ZIP 생성용 하네스 도구 — 피시험 대상이 아니므로 PATH 에 넣지 않고
# 절대경로로 부른다(Termux 의 python3 도 $PREFIX/bin 에 있다).
_CLI_PYTHON="$(command -v python3)"
_CLI_SHA256="$(command -v sha256sum)"

_cli_setup() {
    local sb="$1" name
    export HOME="$sb/home" PREFIX="$sb/usr" TMPDIR="$sb/tmp"
    export TEST_TRACE="$sb/commands.log"
    export CLI_SOURCE_SHA256_BIN="$_CLI_SHA256"
    export PATH="$sb/bin:/usr/bin:/bin"
    unset PROOT_DISTRO PROOT_USER PROOT_ROOTFS_BASE KOREAN_LOCALE_ZIP UI
    unset DISPLAY_SERVER WAYLAND_DISPLAY ANLAND XFCE4_SESSION_COMPOSITOR XDG_CURRENT_DESKTOP
    unset TEST_SHA TEST_REMOVE_RC TEST_CLANG_RC TEST_NPM_INSTALLED TEST_GRUN_RC TEST_DPKG_INSTALLED
    mkdir -p "$HOME/.config/termux-xfce" "$HOME/Desktop" "$sb/bin" "$TMPDIR" \
        "$PREFIX/lib" "$PREFIX/etc" "$PREFIX/bin" "$PREFIX/share/applications"
    touch "$PREFIX/etc/bash.bashrc" "$HOME/.zshrc" "$TEST_TRACE"
    ln -sf "$_CLI_BASH" "$sb/bin/bash"
    # shebang 은 실행 중인 bash 경로로 — Termux 에는 /usr/bin/env 가 없다
    { printf '#!%s\n' "$_CLI_BASH"; cat <<'STUB'
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
    dpkg-query)
        case "${!#}" in
            codex) exit 1 ;;
            *) [ "${TEST_DPKG_INSTALLED:-0}" = 1 ] || exit 1
               printf 'install ok installed\n'; exit 0 ;;
        esac ;;
    wget|curl)
        while [ "$#" -gt 0 ]; do
            case "$1" in
                -O|-o) printf 'download fixture\n' > "$2"; exit 0 ;;
            esac
            shift
        done ;;
    sha256sum)
        # Download payloads are fixtures; the repository C source is real.
        if [ "${1##*/}" = force_gettext.c ]; then exec "$CLI_SOURCE_SHA256_BIN" "$@"; fi
        printf '%s  %s\n' "${TEST_SHA:-}" "$1"; exit 0 ;;
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
    grun) exit "${TEST_GRUN_RC:-0}" ;;
    proot-distro|glib-compile-schemas|gio) exit 0 ;;
esac
echo "Unexpected fixture command: $name $*" >&2
exit 1
STUB
    } > "$sb/bin/stub"
    chmod +x "$sb/bin/stub"
    for name in pkg dpkg dpkg-query wget curl sha256sum tar clang npm grun proot-distro glib-compile-schemas gio; do
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

# 바이너리 내용만 깨진 설치본(세션 강제 종료 등)은 -x 검사를 통과하므로 install 이
# "이미 설치되어 있습니다" 로 빠져 복구가 불가능했다 — 이제 스모크로 걸러 재설치한다.
_test_cli_install_repairs_broken_claude() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"
    export PROOT_DISTRO=""
    source "$APP_DIR/domain/installers/claude_code.sh"
    export TEST_SHA="${CLAUDE_CODE_TARBALL_SHA256[$CLAUDE_CODE_PIN_VERSION]}"
    mkdir -p "$PREFIX/share/claude-code"
    : > "$PREFIX/share/claude-code/claude"; chmod +x "$PREFIX/share/claude-code/claude"
    printf '#!/bin/sh\n' > "$PREFIX/bin/claude"; chmod +x "$PREFIX/bin/claude"
    export TEST_GRUN_RC=1   # ld.so 가 로드를 거부하는 상태
    _cli install claude_code > "$sb/install.log" 2>&1
    assert_file_contains "$sb/install.log" '손상'
    assert_file_contains "$TEST_TRACE" 'sha256sum .*native.tgz'
    assert_file_contains "$PREFIX/share/claude-code/claude" 'native binary fixture'
    cleanup_sandbox "$sb"
}
it 'install on a corrupt Claude binary reinstalls instead of reporting success' _test_cli_install_repairs_broken_claude

_test_cli_install_keeps_healthy_claude() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"
    export PROOT_DISTRO=""
    mkdir -p "$PREFIX/share/claude-code"
    printf 'native binary fixture\n' > "$PREFIX/share/claude-code/claude"
    chmod +x "$PREFIX/share/claude-code/claude"
    printf '#!/bin/sh\n' > "$PREFIX/bin/claude"; chmod +x "$PREFIX/bin/claude"
    export TEST_GRUN_RC=0   # 정상 로드
    _cli install claude_code > "$sb/install.log" 2>&1
    assert_file_contains "$sb/install.log" '이미 설치'
    assert_file_contains "$PREFIX/share/claude-code/claude" 'native binary fixture'
    if grep -q 'native.tgz' "$TEST_TRACE"; then
        echo "[ASSERT] 정상 설치본인데 재다운로드가 일어났다" >&2
        cleanup_sandbox "$sb"; return 1
    fi
    cleanup_sandbox "$sb"
}
it 'install on a healthy Claude binary stays a no-op' _test_cli_install_keeps_healthy_claude

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
_test_cli_retired_app_is_hidden_and_install_rejected() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"
    export PROOT_DISTRO=""
    _cli list > "$sb/list.log"
    if command grep -q '^tor_browser[[:space:]]' "$sb/list.log"; then return 1; fi
    if _cli install tor_browser > "$sb/install.log" 2>&1; then return 1; fi
    assert_file_contains "$sb/install.log" '신규 설치가 중단'
    [ ! -e "$PREFIX/share/applications/tor.desktop" ]
    cleanup_sandbox "$sb"
}
it 'retired Tor is hidden when absent and CLI rejects new installation' _test_cli_retired_app_is_hidden_and_install_rejected

_test_cli_existing_retired_app_can_be_removed() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"
    export PROOT_DISTRO=""
    touch "$PREFIX/share/applications/tor.desktop" "$HOME/Desktop/tor.desktop"
    _cli list 브라우저 > "$sb/list.log"
    assert_file_contains "$sb/list.log" '^tor_browser[[:space:]]'
    _cli status tor_browser > "$sb/status.log"
    assert_file_contains "$sb/status.log" 'tor_browser: 설치됨'
    if _cli install tor_browser > "$sb/install.log" 2>&1; then return 1; fi
    assert_file_contains "$sb/install.log" '신규 설치가 중단'
    _cli remove tor_browser
    _cli remove tor_browser
    [ ! -e "$PREFIX/share/applications/tor.desktop" ]
    [ ! -e "$HOME/Desktop/tor.desktop" ]
    _cli list > "$sb/list-after.log"
    if command grep -q '^tor_browser[[:space:]]' "$sb/list-after.log"; then return 1; fi
    if command grep -q '^proot-distro ' "$TEST_TRACE"; then return 1; fi
    cleanup_sandbox "$sb"
}
it 'existing retired Tor remains visible and native-only CLI removes its leftovers' _test_cli_existing_retired_app_can_be_removed

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
    "$_CLI_PYTHON" - "$KOREAN_LOCALE_ZIP" <<'PY'
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
    assert_file_exists "$PREFIX/lib/force_gettext.so.sha256"
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
_test_locale_upgrade_rebuilds_and_remove_cleans_stamp() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"
    export PROOT_DISTRO=""
    printf 'legacy shared library\n' > "$PREFIX/lib/force_gettext.so"
    source "$APP_DIR/domain/installers/korean_locale.sh"
    app_upgrade_korean_locale
    assert_file_contains "$PREFIX/lib/force_gettext.so" 'shared library fixture'
    local source_hash
    source_hash=$("$_CLI_SHA256" "$APP_DIR/../assets/force_gettext.c")
    assert_eq "${source_hash%% *}" "$(cat "$PREFIX/lib/force_gettext.so.sha256")"
    # A matching marker should skip compilation even if the compiler would fail.
    export TEST_CLANG_RC=42
    app_upgrade_korean_locale
    _cli remove korean_locale
    [ ! -e "$PREFIX/lib/force_gettext.so" ]
    [ ! -e "$PREFIX/lib/force_gettext.so.sha256" ]
    cleanup_sandbox "$sb"
}
_test_locale_upgrade_failure_preserves_old_library() {
    local sb; sb=$(make_sandbox); _cli_setup "$sb"
    printf 'legacy shared library\n' > "$PREFIX/lib/force_gettext.so"
    printf 'old source hash\n' > "$PREFIX/lib/force_gettext.so.sha256"
    export TEST_CLANG_RC=42
    source "$APP_DIR/domain/installers/korean_locale.sh"
    if app_upgrade_korean_locale > "$sb/output" 2>&1; then return 1; fi
    assert_eq 'legacy shared library' "$(cat "$PREFIX/lib/force_gettext.so")"
    assert_eq 'old source hash' "$(cat "$PREFIX/lib/force_gettext.so.sha256")"
    cleanup_sandbox "$sb"
}
if [ -f "$APP_DIR/../domain/locale_ko.sh" ]; then
    it 'missing catalog ZIP makes locale installation fail' _test_cli_locale_requires_zip
    it 'valid ZIP loads parent adapters and builds from parent assets' _test_cli_locale_builds
    it 'compiler failure propagates without leaving a library or launcher' _test_cli_locale_build_fails
    it 'locale upgrade rebuilds once without a ZIP and removal deletes its hash marker' _test_locale_upgrade_rebuilds_and_remove_cleans_stamp
    it 'failed locale upgrade preserves the existing library and source hash' _test_locale_upgrade_failure_preserves_old_library
else
    skip 'parent locale integration requires the Termux_XFCE checkout'
fi

print_results
