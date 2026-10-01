#!/data/data/com.termux/files/usr/bin/bash
# Core review regressions. Every package/download/runtime command is mocked.
_CORE_APP_DIR="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
_CORE_BASH="$BASH"
source "$_CORE_APP_DIR/tests/framework.sh"

_core_setup() {
    _CORE_SANDBOX=$(make_sandbox)
    trap 'cleanup_sandbox "$_CORE_SANDBOX"' EXIT
    export HOME="$_CORE_SANDBOX/home" PREFIX="$_CORE_SANDBOX/usr" TMPDIR="$_CORE_SANDBOX/tmp"
    export PATH="$_CORE_SANDBOX/mock-bin:$PATH"
    export CORE_TRACE="$_CORE_SANDBOX/trace"
    mkdir -p "$HOME" "$PREFIX/bin" "$TMPDIR" "$_CORE_SANDBOX/mock-bin"
    : > "$CORE_TRACE"
    unset _WINE_BACKEND_SH CORE_DPKG_RC CORE_REPAIR_RC CORE_QUERY_RC CORE_QUERY_STATE
    unset CORE_METADATA_RC CORE_BAD_PACKAGE CORE_QUERY_ARCH
    {
        printf '#!%s\n' "$_CORE_BASH"
        cat <<'STUB'
set -eu
tool="${0##*/}"
case "$tool" in
    wget)
        while [ "$#" -gt 0 ]; do
            if [ "$1" = -O ]; then printf 'DEB-PAYLOAD\n' > "$2"; exit 0; fi
            shift
        done
        exit 99 ;;
    sudo) exec "$@" ;;
    dpkg-deb)
        [ "${CORE_METADATA_RC:-0}" -eq 0 ] || exit "$CORE_METADATA_RC"
        case "$3" in
            Package) name="${2##*/}"; printf '%s\n' "${name%.deb}" ;;
            Version) printf '1.0\n' ;;
            Architecture) printf 'arm64\n' ;;
            *) exit 99 ;;
        esac ;;
    dpkg)
        printf 'dpkg %s\n' "$*" >> "$CORE_TRACE"
        exit "${CORE_DPKG_RC:-0}" ;;
    apt-get)
        printf 'repair %s\n' "$*" >> "$CORE_TRACE"
        exit "${CORE_REPAIR_RC:-0}" ;;
    dpkg-query)
        query="${@: -1}"
        printf 'query %s\n' "$query" >> "$CORE_TRACE"
        [ "${CORE_QUERY_RC:-0}" -eq 0 ] || exit "$CORE_QUERY_RC"
        if [ "${CORE_BAD_PACKAGE:-}" = "${query%%:*}" ]; then
            printf 'deinstall ok config-files|1.0|arm64'
        else
            printf '%s|%s' "${CORE_QUERY_STATE:-install ok installed|1.0}" "${CORE_QUERY_ARCH:-arm64}"
        fi ;;
    termux-wake-lock) exit 0 ;;
    box64) printf '%s\n' "$@" > "$HOME/box64-argv" ;;
    *) printf 'Unmocked command: %s %s\n' "$tool" "$*" >&2; exit 99 ;;
esac
STUB
    } > "$_CORE_SANDBOX/mock-bin/stub"
    chmod +x "$_CORE_SANDBOX/mock-bin/stub"
    local tool
    for tool in wget curl sudo dpkg dpkg-deb dpkg-query apt-get apt pkg proot-distro grun \
        wine wineserver termux-wake-lock box64; do
        ln -s stub "$_CORE_SANDBOX/mock-bin/$tool"
    done
    source "$_CORE_APP_DIR/lib/wine_backend.sh"
    source "$_CORE_APP_DIR/domain/installers/wine.sh"
    source "$_CORE_APP_DIR/domain/installers/claude_code.sh"
    source "$_CORE_APP_DIR/adapters/output/pkg_ubuntu.sh"
}

_core_native_fixture() {
    _core_setup
    mkdir -p "$PREFIX/glibc/bin" "$PREFIX/glibc/lib" "$HOME/.wine-staging/bin"
    printf '#!%s\n' "$_CORE_BASH" > "$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
    cat >> "$PREFIX/glibc/lib/ld-linux-aarch64.so.1" <<'STUB'
set -eu
[ "${LD_PRELOAD+x}" != x ] || exit 98
[ "$1" = --library-path ] && [ "$2" = "$PREFIX/glibc/lib" ] || exit 97
[ "$3" = "$PREFIX/glibc/bin/box64" ] || exit 96
case "$4" in
    */wineserver) printf '%s\n' "$@" > "$HOME/server-argv" ;;
    */wine) printf '%s\n' "$@" > "$HOME/wine-argv" ;;
    *) exit 95 ;;
esac
STUB
    chmod +x "$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
    touch "$PREFIX/glibc/bin/box64" "$HOME/.wine-staging/bin/wine" "$HOME/.wine-staging/bin/wineserver"
    chmod +x "$PREFIX/glibc/bin/box64" "$HOME/.wine-staging/bin/wine" "$HOME/.wine-staging/bin/wineserver"
    _wine_write_box64_native_wrapper
}

_test_native_wine_uses_box64_and_preserves_argv() {
    _core_native_fixture
    LD_PRELOAD= bash "$_WINE_BIN" 'C:\Program Files\Notepad++\notepad++.exe' 'argument with spaces' '%literal'
    local -a args=()
    mapfile -t args < "$HOME/wine-argv"
    assert_eq "$PREFIX/glibc/bin/box64" "${args[2]}"
    assert_eq "$HOME/.wine-staging/bin/wine" "${args[3]}"
    assert_eq 'C:\Program Files\Notepad++\notepad++.exe' "${args[4]}"
    assert_eq 'argument with spaces' "${args[5]}"
    assert_eq '%literal' "${args[6]}"
    # The server is started in the background; observe its mock completion.
    local i
    for i in {1..100}; do [ -f "$HOME/server-argv" ] && break; sleep .01; done
    assert_file_contains "$HOME/server-argv" "$PREFIX/glibc/bin/box64"
    assert_file_contains "$HOME/server-argv" "$HOME/.wine-staging/bin/wineserver"
}

_test_native_wine_rejects_missing_box64() {
    _core_native_fixture
    rm "$PREFIX/glibc/bin/box64"
    if bash "$_WINE_BIN" explorer; then return 1; fi
    [ ! -e "$HOME/wine-argv" ]
}

_test_existing_native_wine_checks_runtime_dependencies() {
    _core_setup
    mkdir -p "$_WINE_NATIVE_DIR/bin"
    touch "$_WINE_NATIVE_DIR/bin/wine"; chmod +x "$_WINE_NATIVE_DIR/bin/wine"
    local installed=''
    termux_pkg_enable_repo() { return 0; }
    termux_pkg_install() { installed="$*"; return 42; }
    if _wine_install_native; then return 1; fi
    assert_eq 'glibc-runner box64-glibc' "$installed"
    [ ! -e "$_WINE_BIN" ]
}

_core_wine_proot_exec() {
    [ "$1" = sudo ] && [ "$2" = bash ] && [ "$3" = -c ] || return 99
    local snippet="$4"
    snippet="${snippet//\/opt\/wine-staging/$_CORE_SANDBOX/wine-staging}"
    snippet="${snippet//\/tmp\/wine-staging.tar.xz/$TMPDIR/wine-staging.tar.xz}"
    snippet="${snippet//\/usr\/local\/bin/$_CORE_SANDBOX/local-bin}"
    bash -c "$snippet"
}

_test_missing_file_stops_wine_before_download() {
    _core_setup
    fetch_verified_src() { printf 'fetch_verified() { printf download >> "$CORE_TRACE"; return 99; }'; }
    command() {
        if [ "${1:-}" = -v ] && [ "${2:-}" = file ]; then return 1; fi
        builtin command "$@"
    }
    export -f command
    proot_exec_wine() { _core_wine_proot_exec "$@"; }
    if _wine_install_tarball_proot; then return 1; fi
    [ ! -s "$CORE_TRACE" ]
    [ ! -e "$_CORE_SANDBOX/wine-staging" ]
}

_core_wine_tarball_fixture() {
    _core_setup
    export CORE_WINE_TREE="$_CORE_SANDBOX/wine-staging"
    mkdir -p "$_CORE_SANDBOX/local-bin"
    fetch_verified_src() { printf 'fetch_verified() { printf archive > "$2"; }'; }
    file() { printf 'ELF 64-bit x86-64\n'; }
    tar() {
        mkdir -p "$CORE_WINE_TREE/bin"
        local program
        for program in wine wineserver; do
            printf '%s original ELF\n' "$program" > "$CORE_WINE_TREE/bin/$program"
            chmod +x "$CORE_WINE_TREE/bin/$program"
        done
    }
    export -f file tar
    proot_exec_wine() { _core_wine_proot_exec "$@"; }
}

_test_proot_wine_creates_and_uses_box64_wrappers() {
    _core_wine_tarball_fixture
    _wine_install_tarball_proot
    assert_eq 'wine original ELF' "$(cat "$CORE_WINE_TREE/bin/.elf/wine")"
    assert_eq 'wineserver original ELF' "$(cat "$CORE_WINE_TREE/bin/.elf/wineserver")"
    bash "$CORE_WINE_TREE/bin/wine" 'argument with spaces'
    local -a args=()
    mapfile -t args < "$HOME/box64-argv"
    assert_eq "$CORE_WINE_TREE/bin/.elf/wine" "${args[0]}"
    assert_eq 'argument with spaces' "${args[1]}"
}

_test_proot_wine_rejects_failed_elf_classification() {
    _core_wine_tarball_fixture
    mkdir -p "$CORE_WINE_TREE/bin/.elf"
    touch "$CORE_WINE_TREE/bin/.elf/wine" "$CORE_WINE_TREE/bin/.elf/wineserver"
    chmod +x "$CORE_WINE_TREE/bin/.elf/"*
    file() { return 42; }
    export -f file
    if _wine_install_tarball_proot; then return 1; fi
    [ ! -e "$_CORE_SANDBOX/local-bin/wine" ]
    # A successful classifier with a non-x86 result must also reject stale ELFs.
    file() { printf 'ASCII text\n'; }
    export -f file
    if _wine_install_tarball_proot; then return 1; fi
    [ ! -e "$_CORE_SANDBOX/local-bin/wine" ]
}

_test_proot_installed_guard_requires_current_wrappers() {
    _core_wine_tarball_fixture
    mkdir -p "$CORE_WINE_TREE/bin/.elf"
    touch "$CORE_WINE_TREE/bin/.elf/wine" "$CORE_WINE_TREE/bin/.elf/wineserver"
    chmod +x "$CORE_WINE_TREE/bin/.elf/"*
    tar
    export PROOT_DISTRO=ubuntu PROOT_USER=testuser
    local updates=0 launchers=0
    has_proot_distro() { return 0; }
    proot_pkg_update() { updates=$((updates + 1)); return 42; }
    _wine_create_launchers() { launchers=$((launchers + 1)); }
    proot_exec() {
        [ "$1" = env ] && [ "$3" = bash ] && [ "$4" = -c ] || return 99
        local snippet="$5"
        snippet="${snippet//\/opt\/wine-staging/$CORE_WINE_TREE}"
        bash -c "$snippet"
    }
    if app_install_wine >/dev/null; then return 1; fi
    assert_eq 1 "$updates"
    assert_eq 0 "$launchers"
    _wine_install_tarball_proot >/dev/null
    app_install_wine >/dev/null
    assert_eq 1 "$updates"
    assert_eq 1 "$launchers"
}

_test_ubuntu_box64_installs_file_before_build() {
    _core_setup
    local packages='' built=0
    proot_pkg_install() { packages=" $* "; }
    proot_exec() { built=$((built + 1)); }
    proot_pkg_install_box64
    [[ "$packages" == *' file '* ]]
    assert_eq 1 "$built"
    proot_pkg_install() { return 42; }
    if proot_pkg_install_box64; then return 1; fi
    assert_eq 1 "$built"
}

_core_deb_setup() {
    _core_setup
    proot_exec() { "$@"; }
    _CORE_SHA=$(printf 'DEB-PAYLOAD\n' | sha256sum)
    _CORE_SHA="${_CORE_SHA%% *}"
}

_core_deb_install() { proot_pkg_install_deb_url "https://example.invalid/foo.deb|$_CORE_SHA"; }
_core_debs_cleaned() {
    if compgen -G "$TMPDIR/app-debs.*" >/dev/null; then return 1; fi
}

_test_deb_repair_failure_propagates() {
    _core_deb_setup
    export CORE_DPKG_RC=42 CORE_REPAIR_RC=43
    if _core_deb_install; then return 1; fi
    assert_file_contains "$CORE_TRACE" '^dpkg '
    assert_file_contains "$CORE_TRACE" '^repair '
    _core_debs_cleaned
}

_test_deb_recovered_dependency_failure_succeeds() {
    _core_deb_setup
    export CORE_DPKG_RC=42
    _core_deb_install
    assert_file_contains "$CORE_TRACE" '^query foo:arm64$'
    _core_debs_cleaned
}

_test_deb_failed_or_removed_package_is_rejected() {
    _core_deb_setup
    export CORE_DPKG_RC=42 CORE_BAD_PACKAGE=foo
    if _core_deb_install; then return 1; fi
    _core_debs_cleaned
}

_test_deb_old_installed_version_is_rejected() {
    _core_deb_setup
    export CORE_QUERY_STATE='install ok installed|0.9'
    if _core_deb_install; then return 1; fi
    _core_debs_cleaned
}

_test_deb_wrong_architecture_is_rejected() {
    _core_deb_setup
    export CORE_QUERY_ARCH=amd64
    if _core_deb_install; then return 1; fi
    _core_debs_cleaned
}

_test_deb_query_failure_is_rejected() {
    _core_deb_setup
    export CORE_QUERY_RC=42
    if _core_deb_install; then return 1; fi
    _core_debs_cleaned
}

_test_deb_metadata_failure_stops_install() {
    _core_deb_setup
    export CORE_METADATA_RC=42
    if _core_deb_install; then return 1; fi
    [ ! -s "$CORE_TRACE" ]
    _core_debs_cleaned
}

_test_deb_batch_verifies_each_package() {
    _core_deb_setup
    export CORE_BAD_PACKAGE=bar
    if proot_pkg_install_deb_url "https://example.invalid/foo.deb|$_CORE_SHA" \
        "https://example.invalid/bar.deb|$_CORE_SHA"; then return 1; fi
    assert_file_contains "$CORE_TRACE" '^query foo:arm64$'
    assert_file_contains "$CORE_TRACE" '^query bar:arm64$'
    _core_debs_cleaned
}

_core_claude_fixture() {
    _core_setup
    mkdir -p "$CLAUDE_CODE_PREFIX"
    printf old-good > "$CLAUDE_CODE_PREFIX/claude"
    printf old-package > "$CLAUDE_CODE_PREFIX/package.json"
    printf 2.1.261 > "$CLAUDE_CODE_VERSION_FILE"
    printf old-wrapper > "$CLAUDE_CODE_BIN_PATH"
    chmod +x "$CLAUDE_CODE_PREFIX/claude" "$CLAUDE_CODE_BIN_PATH"
    _CORE_DOWNLOADS=0
    _claude_code_download_native() { _CORE_DOWNLOADS=$((_CORE_DOWNLOADS + 1)); return 99; }
    _claude_code_smoke_check() { return 99; }
}

_core_claude_original_intact() {
    assert_eq old-good "$(cat "$CLAUDE_CODE_PREFIX/claude")"
    assert_eq old-package "$(cat "$CLAUDE_CODE_PREFIX/package.json")"
    assert_eq 2.1.261 "$(_claude_code_installed_version)"
    assert_eq old-wrapper "$(cat "$CLAUDE_CODE_BIN_PATH")"
    assert_eq 0 "$_CORE_DOWNLOADS"
    [ ! -e "$CLAUDE_CODE_PREFIX/claude.bak.v2.1.261" ]
    if compgen -G "$CLAUDE_CODE_PREFIX/.backup.*" >/dev/null; then return 1; fi
}

_test_claude_binary_backup_failure_preserves_current() {
    _core_claude_fixture
    cp() { printf partial > "${@: -1}"; return 42; }
    if app_upgrade_claude_code; then return 1; fi
    _core_claude_original_intact
}

_test_claude_metadata_backup_failure_preserves_current() {
    _core_claude_fixture
    cp() {
        if [[ "$*" == *'/package.json '* ]]; then printf partial > "${@: -1}"; return 42; fi
        command cp "$@"
    }
    if app_upgrade_claude_code; then return 1; fi
    _core_claude_original_intact
}

_test_claude_backup_retry_publishes_complete_files() {
    _core_claude_fixture
    cp() { printf partial > "${@: -1}"; return 42; }
    if _claude_code_backup_current 2.1.261; then return 1; fi
    unset -f cp
    _claude_code_backup_current 2.1.261
    assert_eq old-good "$(cat "$CLAUDE_CODE_PREFIX/claude.bak.v2.1.261")"
    assert_eq old-package "$(cat "$CLAUDE_CODE_PREFIX/package.json.bak.v2.1.261")"
    [ -x "$CLAUDE_CODE_PREFIX/claude.bak.v2.1.261" ]
    if compgen -G "$CLAUDE_CODE_PREFIX/.backup.*" >/dev/null; then return 1; fi
}

_test_claude_existing_backup_is_preserved() {
    _core_claude_fixture
    printf known-good > "$CLAUDE_CODE_PREFIX/claude.bak.v2.1.261"
    cp() { return 42; }
    _claude_code_backup_current 2.1.261
    assert_eq known-good "$(cat "$CLAUDE_CODE_PREFIX/claude.bak.v2.1.261")"
}

describe 'review — native Wine and Ubuntu ELF prerequisites'
it 'native Wine and wineserver use Box64 and retain each argument' _test_native_wine_uses_box64_and_preserves_argv
it 'native Wine stops when Box64 is missing' _test_native_wine_rejects_missing_box64
it 'an existing native Wine tree still checks runtime package dependencies' _test_existing_native_wine_checks_runtime_dependencies
it 'missing file rejects proot Wine before downloading or extracting' _test_missing_file_stops_wine_before_download
it 'proot Wine generates working Box64 wrappers for both required ELF programs' _test_proot_wine_creates_and_uses_box64_wrappers
it 'failed or non-x86 ELF classification cannot reuse stale Wine ELF files' _test_proot_wine_rejects_failed_elf_classification
it 'the installed guard rejects raw Wine programs beside stale ELF files' _test_proot_installed_guard_requires_current_wrappers
it 'Ubuntu installs file before building Box64 and stops on package failure' _test_ubuntu_box64_installs_file_before_build
describe 'review — verified Ubuntu deb installation'
it 'dpkg and dependency repair failures reach the caller' _test_deb_repair_failure_propagates
it 'dependency failure succeeds only after repair and installed version verification' _test_deb_recovered_dependency_failure_succeeds
it 'repair that removes or leaves a package unconfigured is rejected' _test_deb_failed_or_removed_package_is_rejected
it 'an older installed version cannot hide a failed deb upgrade' _test_deb_old_installed_version_is_rejected
it 'installed architecture must match the downloaded deb' _test_deb_wrong_architecture_is_rejected
it 'a package status query failure reaches the caller' _test_deb_query_failure_is_rejected
it 'invalid deb metadata prevents package installation' _test_deb_metadata_failure_stops_install
it 'a batch checks the state of every downloaded package' _test_deb_batch_verifies_each_package
describe 'review — Claude backup failure preservation'
it 'binary backup failure stops upgrade and preserves the original installation' _test_claude_binary_backup_failure_preserves_current
it 'metadata backup failure also stops upgrade before replacement' _test_claude_metadata_backup_failure_preserves_current
it 'retry after a partial backup publishes complete executable and metadata copies' _test_claude_backup_retry_publishes_complete_files
it 'an existing known good backup remains unchanged' _test_claude_existing_backup_is_preserved
print_results
