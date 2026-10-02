#!/data/data/com.termux/files/usr/bin/bash
# Wine ownership and interrupted-install regression checks. External commands
# have executable guards; every download, package operation and container is a mock.
_WCTX_APP_DIR="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
source "$_WCTX_APP_DIR/tests/framework.sh"
_WCTX_BASH="${BASH:-$(command -v bash)}"

_wctx_setup() {
    _WCTX_SB=$(mktemp -d "${TMPDIR:-/tmp}/wine-context.XXXXXX")
    trap 'command rm -rf "$_WCTX_SB"' EXIT
    export HOME="$_WCTX_SB/home" PREFIX="$_WCTX_SB/usr" TMPDIR="$_WCTX_SB/tmp"
    export PROOT_DISTRO=ubuntu PROOT_USER=testuser PROOT_ROOTFS_BASE="$_WCTX_SB/rootfs"
    export WCTX_TRACE="$_WCTX_SB/trace" WCTX_ROOT="$_WCTX_SB"
    export PATH="$_WCTX_SB/mock-bin:$PREFIX/bin:$PATH"
    unset LD_PRELOAD WINEPREFIX WINE_CONTEXT_RUNNER _WINE_BACKEND_SH _PROOT_PATH_SH
    mkdir -p "$HOME/Desktop" "$PREFIX/bin" "$PREFIX/share/applications" "$TMPDIR" \
        "$_WCTX_SB/mock-bin" "$PROOT_ROOTFS_BASE/installed-rootfs/ubuntu/home/testuser"
    {
        printf '#!%s\n' "$_WCTX_BASH"
        printf 'echo "unexpected external command: ${0##*/} $*" >&2\nexit 99\n'
    } > "$_WCTX_SB/mock-bin/guard"
    chmod +x "$_WCTX_SB/mock-bin/guard"
    local tool
    for tool in pkg apt apt-get pacman sudo wget curl git grun box64 \
        wine wineboot wineserver proot-distro termux-wake-lock gio; do
        ln -s guard "$_WCTX_SB/mock-bin/$tool"
    done
    source "$_WCTX_APP_DIR/lib/proot_path.sh"
    source "$_WCTX_APP_DIR/lib/wine_backend.sh"
    source "$_WCTX_APP_DIR/domain/desktop.sh"
    source "$_WCTX_APP_DIR/adapters/output/pkg_proot_base.sh"
    local id
    for id in wine notepadpp sevenzip sumatrapdf winmerge; do
        source "$_WCTX_APP_DIR/domain/installers/$id.sh"
    done
    SCRIPT_DIR="$_WCTX_APP_DIR"
    termux_pkg_enable_repo() { :; }
    termux_pkg_install() { :; }
    fetch_verified() { printf archive > "$2"; }
    fetch_verified_src() { declare -f fetch_verified; }
}

_wctx_native_runner() {
    local backend="$1"
    {
        printf '#!%s\n' "$_WCTX_BASH"
        printf 'backend=%q\n' "$backend"
        cat <<'STUB'
if [[ "${1:-}" = */7z_install.exe ]]; then
    mkdir -p "$WINEPREFIX/drive_c/7-Zip"
    printf sevenzip > "$WINEPREFIX/drive_c/7-Zip/7zFM.exe"
else
    printf '%s|%s\n' "$backend" "$WINEPREFIX" > "$WCTX_TRACE"
    printf '<%s>\n' "$@" >> "$WCTX_TRACE"
fi
STUB
    } > "$PREFIX/bin/wine-$backend"
    chmod +x "$PREFIX/bin/wine-$backend"
}

_wctx_mock_unzip() {
    {
        printf '#!%s\n' "$_WCTX_BASH"
        cat <<'STUB'
set -eu
archive=$2
shift 2
[ "$1" = -d ] || exit 98
out=$2
mkdir -p "$out"
case "$archive" in
    */npp.zip) printf npp > "$out/notepad++.exe" ;;
    */sumatra.zip) printf sumatra > "$out/SumatraPDF-3.6.1-64.exe" ;;
    */winmerge.zip) mkdir -p "$out/WinMerge"; printf merge > "$out/WinMerge/WinMergeU.exe" ;;
    *) exit 97 ;;
esac
STUB
    } > "$_WCTX_SB/mock-bin/unzip"
    chmod +x "$_WCTX_SB/mock-bin/unzip"
}

_wctx_mock_container() {
    rm "$_WCTX_SB/mock-bin/proot-distro"
    {
        printf '#!%s\n' "$_WCTX_BASH"
        cat <<'STUB'
set -eu
[ "$1" = login ] || exit 98
distro=$2; shift 2
[ "$1" = --user ] || exit 97
user=$2; shift 2
[ "$1" = --shared-tmp ] && [ "$2" = -- ] || exit 96
shift 2
base=${PROOT_ROOTFS_BASE:-$PREFIX/var/lib/proot-distro}
export HOME="$base/installed-rootfs/$distro/home/$user"
printf 'container:%s:%s\n' "$distro" "$user" > "$WCTX_TRACE"
args=()
for arg in "$@"; do
    arg="${arg//\/opt\/wine-staging\/bin\/wine/$WCTX_ROOT/container-wine}"
    args+=("$arg")
done
exec "${args[@]}"
STUB
    } > "$_WCTX_SB/mock-bin/proot-distro"
    {
        printf '#!%s\n' "$_WCTX_BASH"
        cat <<'STUB'
printf 'prefix:%s\n' "$WINEPREFIX" >> "$WCTX_TRACE"
printf '<%s>\n' "$@" >> "$WCTX_TRACE"
STUB
    } > "$_WCTX_SB/container-wine"
    chmod +x "$_WCTX_SB/mock-bin/proot-distro" "$_WCTX_SB/container-wine"
}

_wctx_tree() {
    local tree="$1"
    mkdir -p "$tree/bin" "$tree/lib/wine/x86_64-unix" "$tree/lib/wine/x86_64-windows"
    printf wine > "$tree/bin/wine"; printf server > "$tree/bin/wineserver"
    chmod +x "$tree/bin/wine" "$tree/bin/wineserver"
    printf ntdll > "$tree/lib/wine/x86_64-unix/ntdll.so"
    printf kernel > "$tree/lib/wine/x86_64-windows/kernel32.dll"
}

_test_apps_keep_original_backend() {
    _wctx_setup
    _wctx_native_runner hangover
    _wctx_native_runner box64
    _wctx_mock_unzip
    wine_backend_set hangover
    local id rel original other
    for id in sevenzip notepadpp sumatrapdf winmerge; do
        "app_install_$id" >/dev/null
        rel=$(_wine_app_relpath "$id")
        original="$HOME/.wine-hangover/drive_c/$rel"
        other="$HOME/.wine/drive_c/$rel"
        [ -f "$original" ]
        mkdir -p "${other%/*}"; printf untouched > "$other"
        wine_backend_set box64
        "app_is_installed_$id"
        bash "$PREFIX/bin/wine-app-$id" 'file name with spaces' '%literal'
        assert_file_contains "$WCTX_TRACE" "hangover|$HOME/.wine-hangover"
        assert_file_contains "$WCTX_TRACE" '<file name with spaces>'
        assert_file_contains "$WCTX_TRACE" '<%literal>'
        assert_file_contains "$PREFIX/share/applications/$id.desktop" "^Exec=wine-app-$id %f$"
        "app_remove_$id"
        [ ! -e "$original" ] && [ -f "$other" ]
        [ ! -e "$_WINE_APP_STATE/$id.context" ]
        [ ! -e "$PREFIX/share/applications/$id.desktop" ]
        assert_eq box64 "$(wine_backend)"
        wine_backend_set hangover
    done
}
it 'all four Wine apps launch and remove their installed backend after switching' _test_apps_keep_original_backend

_test_native_remains_native_after_proot_added() {
    _wctx_setup
    _wctx_native_runner box64
    # Legacy native wrapper: no new context record yet.
    printf '\n# native $HOME/.wine-staging/bin/wine\n' >> "$PREFIX/bin/wine-box64"
    wine_backend_set box64
    wine_exec_shell 'wine "argument with spaces"'
    assert_file_contains "$WCTX_TRACE" "box64|$HOME/.wine"
    assert_eq 'box64|native|||' "$(wine_backend_context)"
}
it 'legacy native Wine keeps its host routing after a proot container is configured' _test_native_remains_native_after_proot_added

_test_proot_apps_keep_container_user_and_base() {
    _wctx_setup
    _wctx_mock_container
    _wctx_native_runner box64
    local saved_base="$PROOT_ROOTFS_BASE" rel
    wine_backend_set box64
    wine_backend_record_context proot ubuntu testuser "$saved_base"
    rel=$(_wine_app_relpath notepadpp)
    mkdir -p "$saved_base/installed-rootfs/ubuntu/home/testuser/.wine/drive_c/${rel%/*}"
    printf original > "$saved_base/installed-rootfs/ubuntu/home/testuser/.wine/drive_c/$rel"
    printf '[Desktop Entry]\nExec=wine old\n' > "$PREFIX/share/applications/notepadpp.desktop"
    wine_app_record notepadpp
    PROOT_DISTRO=archlinux PROOT_USER=other PROOT_ROOTFS_BASE="$_WCTX_SB/other-rootfs"
    app_is_installed_notepadpp
    bash "$PREFIX/bin/wine-app-notepadpp" 'argument with spaces'
    assert_file_contains "$WCTX_TRACE" '^container:ubuntu:testuser$'
    assert_file_contains "$WCTX_TRACE" '<C:\\Program Files\\Notepad++\\notepad++.exe>'
    assert_file_contains "$WCTX_TRACE" '<argument with spaces>'
    app_remove_notepadpp
    [ ! -e "$saved_base/installed-rootfs/ubuntu/home/testuser/.wine/drive_c/$rel" ]
    assert_eq archlinux "$PROOT_DISTRO"
    assert_eq other "$PROOT_USER"
    assert_eq "$_WCTX_SB/other-rootfs" "$PROOT_ROOTFS_BASE"
}
it 'a recorded proot app retains its distro, user and rootfs base after config changes' _test_proot_apps_keep_container_user_and_base

_test_legacy_apps_migrate_original_container() {
    _wctx_setup
    _wctx_mock_container
    _wctx_native_runner box64
    PROOT_DISTRO=archlinux PROOT_USER=current
    local rel rootfs="$PROOT_ROOTFS_BASE/installed-rootfs/ubuntu"
    rel=$(_wine_app_relpath winmerge)
    mkdir -p "$rootfs/home/olduser/.wine/drive_c/${rel%/*}"
    printf original > "$rootfs/home/olduser/.wine/drive_c/$rel"
    printf '[Desktop Entry]\nExec=wine old\n' > "$PREFIX/share/applications/winmerge.desktop"
    app_is_installed_winmerge
    assert_eq "box64|proot|ubuntu|olduser|$PROOT_ROOTFS_BASE" "$(wine_app_context winmerge)"
    bash "$PREFIX/bin/wine-app-winmerge"
    assert_file_contains "$WCTX_TRACE" '^container:ubuntu:olduser$'
    app_remove_winmerge
    [ ! -e "$rootfs/home/olduser/.wine/drive_c/$rel" ]
}
it 'desktop-only legacy apps migrate the container/user holding their executable' _test_legacy_apps_migrate_original_container

_test_removal_failure_keeps_ownership() {
    _wctx_setup
    _wctx_native_runner hangover
    wine_backend_set hangover
    local rel; rel=$(_wine_app_relpath sevenzip)
    mkdir -p "$HOME/.wine-hangover/drive_c/${rel%/*}"
    printf original > "$HOME/.wine-hangover/drive_c/$rel"
    printf desktop > "$PREFIX/share/applications/sevenzip.desktop"
    wine_app_record sevenzip
    wine_exec_shell() { return 42; }
    if app_remove_sevenzip; then return 1; fi
    [ -f "$_WINE_APP_STATE/sevenzip.context" ]
    [ -x "$PREFIX/bin/wine-app-sevenzip" ]
    [ -f "$PREFIX/share/applications/sevenzip.desktop" ]
    [ -f "$HOME/.wine-hangover/drive_c/$rel" ]
}
it 'a failed app removal keeps its recorded ownership and launchers' _test_removal_failure_keeps_ownership

_test_partial_native_tree_is_repaired() {
    _wctx_setup
    local fetches=0
    mkdir -p "$_WINE_NATIVE_DIR/bin"
    printf oldpartial > "$_WINE_NATIVE_DIR/bin/wine"; chmod +x "$_WINE_NATIVE_DIR/bin/wine"
    fetch_verified() { fetches=$((fetches + 1)); printf archive > "$2"; }
    tar() { mkdir -p "$4/bin"; printf newpartial > "$4/bin/wine"; chmod +x "$4/bin/wine"; return 42; }
    if _wine_install_native >/dev/null; then return 1; fi
    assert_eq oldpartial "$(cat "$_WINE_NATIVE_DIR/bin/wine")"
    [ ! -e "$_WINE_BOX64_CONTEXT" ] && [ ! -e "$_WINE_BIN" ]
    tar() { _wctx_tree "$4"; }
    _wine_install_native >/dev/null
    _wine_native_tree_complete "$_WINE_NATIVE_DIR"
    assert_eq 2 "$fetches"
    assert_eq 'box64|native|||' "$(wine_backend_context box64)"
    _wine_install_native >/dev/null
    assert_eq 2 "$fetches"
}
it 'failed native extraction preserves the old tree and a retry publishes a complete bundle' _test_partial_native_tree_is_repaired

_test_failed_native_publish_restores_previous_tree() {
    _wctx_setup
    mkdir -p "$_WINE_NATIVE_DIR/bin"
    printf oldpartial > "$_WINE_NATIVE_DIR/bin/wine"; chmod +x "$_WINE_NATIVE_DIR/bin/wine"
    tar() { _wctx_tree "$4"; }
    mv() {
        if [[ "$1" = "${_WINE_NATIVE_DIR}.stage."* ]] && [ "$2" = "$_WINE_NATIVE_DIR" ] && [[ "$1" != *.previous ]]; then
            return 42
        fi
        command mv "$@"
    }
    if _wine_install_native >/dev/null; then return 1; fi
    assert_eq oldpartial "$(cat "$_WINE_NATIVE_DIR/bin/wine")"
    [ ! -e "$_WINE_BOX64_CONTEXT" ] && [ ! -e "$_WINE_BIN" ]
}
it 'a failed native tree publication restores the previous installation' _test_failed_native_publish_restores_previous_tree

_test_proot_backend_wrapper_is_pinned() {
    _wctx_setup
    _wctx_mock_container
    has_proot_distro() { return 0; }
    _wine_create_launchers
    PROOT_DISTRO=archlinux PROOT_USER=other
    printf 'PROOT_DISTRO=""\nPROOT_USER=other\n' > "$HOME/.config/termux-xfce/config"
    bash "$_WINE_BIN" 'argument with spaces'
    assert_file_contains "$WCTX_TRACE" '^container:ubuntu:testuser$'
    assert_file_contains "$WCTX_TRACE" '<argument with spaces>'
    assert_eq "box64|proot|ubuntu|testuser|$PROOT_ROOTFS_BASE" "$(wine_backend_context box64)"
}
it 'the proot backend wrapper retains its installed target after desktop config changes' _test_proot_backend_wrapper_is_pinned

_test_native_backend_removal_after_proot_added() {
    _wctx_setup
    _wctx_native_runner box64
    wine_backend_record_context native
    mkdir -p "$_WINE_NATIVE_DIR/bin"
    printf fixture > "$_WINE_NATIVE_DIR/bin/wine"
    proot_exec() { echo 'unexpected container removal' >&2; return 99; }
    app_remove_wine
    [ ! -e "$_WINE_NATIVE_DIR" ] && [ ! -e "$_WINE_BIN" ]
    [ ! -e "$_WINE_BOX64_CONTEXT" ]
}
it 'removing native Wine after adding proot removes the native implementation' _test_native_backend_removal_after_proot_added

_test_native_app_keeps_snapshot_after_mode_change() {
    _wctx_setup
    _wctx_native_runner box64
    wine_backend_set box64
    local rel; rel=$(_wine_app_relpath notepadpp)
    mkdir -p "$HOME/.wine/drive_c/${rel%/*}"
    printf original > "$HOME/.wine/drive_c/$rel"
    printf '[Desktop Entry]\nExec=wine old\n' > "$PREFIX/share/applications/notepadpp.desktop"
    wine_app_record notepadpp
    wine_backend_record_context proot ubuntu testuser "$PROOT_ROOTFS_BASE"
    printf '#!%s\nexit 99\n' "$_WCTX_BASH" > "$PREFIX/bin/wine-box64"
    app_is_installed_notepadpp
    bash "$PREFIX/bin/wine-app-notepadpp" 'saved native argument'
    assert_file_contains "$WCTX_TRACE" "box64|$HOME/.wine"
    assert_file_contains "$WCTX_TRACE" '<saved native argument>'
    app_remove_notepadpp
    [ ! -e "$HOME/.wine/drive_c/$rel" ]
}
it 'a native app keeps its original runner when Box64 is replaced by a proot wrapper' _test_native_app_keeps_snapshot_after_mode_change

_test_native_verify_rejects_partial_marker() {
    _wctx_setup
    _wctx_native_runner box64
    printf desktop > "$_WINE_DESKTOP"
    mkdir -p "$_WINE_NATIVE_DIR/bin"
    printf partial > "$_WINE_NATIVE_DIR/bin/wine"; chmod +x "$_WINE_NATIVE_DIR/bin/wine"
    app_is_installed_wine
    if app_verify_wine; then return 1; fi
    _wctx_tree "$_WINE_NATIVE_DIR"
    app_verify_wine
}
it 'CLI verification rejects a desktop marker over an incomplete native Wine tree' _test_native_verify_rejects_partial_marker

_test_context_data_is_not_executed() {
    _wctx_setup
    mkdir -p "$_WINE_APP_STATE"
    printf '%s\n' 'box64|proot|$(touch "$HOME/unwanted")|testuser|' > "$_WINE_APP_STATE/notepadpp.context"
    if wine_app_context notepadpp; then return 1; fi
    [ ! -e "$HOME/unwanted" ]
}
it 'invalid ownership records are rejected as data without shell evaluation' _test_context_data_is_not_executed

print_results
