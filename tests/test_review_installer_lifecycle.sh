#!/data/data/com.termux/files/usr/bin/bash
# No package or host filesystem changes: container commands are sandbox fixtures.
_LIFE_ROOT="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
_LIFE_BASH="$BASH"
source "$_LIFE_ROOT/tests/framework.sh"

_life_setup() {
    _LIFE_SANDBOX=$(make_sandbox)
    export _LIFE_SANDBOX
    trap 'cleanup_sandbox "$_LIFE_SANDBOX"' EXIT
    export HOME="$_LIFE_SANDBOX/home" PREFIX="$_LIFE_SANDBOX/usr" TMPDIR="$_LIFE_SANDBOX/tmp"
    export LIFE_TRACE="$_LIFE_SANDBOX/trace"
    mkdir -p "$HOME/.config/termux-xfce" "$PREFIX/bin" "$TMPDIR"
    : > "$LIFE_TRACE"
    source "$_LIFE_ROOT/domain/installers/thorium.sh"
    source "$_LIFE_ROOT/domain/installers/chroot_ng.sh"
    has_proot_distro() { return 0; }
    desktop_register_proot() { printf 'desktop-register\n' >> "$LIFE_TRACE"; }
    desktop_remove() { printf 'desktop-remove\n' >> "$LIFE_TRACE"; }
    fetch_verified_src() {
        printf '%s\n' 'fetch_verified() { printf "fixture\n" > "$2"; }'
    }
    proot_exec() {
        [ "$1" = sudo ] && [ "$2" = bash ] && [ "$3" = -c ] || return 98
        shift 3
        "$_LIFE_BASH" -c "$@"
    }
}

_life_container_fixtures() {
    export LIFE_DPKG_STATE=installed LIFE_QUERY_RC=0 LIFE_DPKG_RC=0 LIFE_EXTRACT_RC=0 LIFE_EXTRACTOR=dpkg-deb
    # All tools used to mutate rootfs are shell functions in the child bash.
    command() {
        if [ "$1" = -v ]; then
            case "$2" in
                dpkg-deb|ar) [ "$2" = "$LIFE_EXTRACTOR" ] || return 1 ;;
                dpkg-query|thorium-browser) ;;
                *) return 98 ;;
            esac
            printf '%s\n' "$2"
        else
            builtin command "$@"
        fi
    }
    mktemp() { builtin command mktemp -d "$TMPDIR/thorium.XXXXXX"; }
    dpkg-deb() {
        printf 'extract %s\n' "$*" >> "$LIFE_TRACE"
        [ "$1" = -x ] && [ "$3" = / ] || return 98
        return "$LIFE_EXTRACT_RC"
    }
    ar() { printf 'ar %s\n' "$*" >> "$LIFE_TRACE"; printf fixture > data.tar.xz; }
    tar() { printf 'tar %s\n' "$*" >> "$LIFE_TRACE"; return "$LIFE_EXTRACT_RC"; }
    dpkg-query() {
        printf 'query %s\n' "$*" >> "$LIFE_TRACE"
        [ "$LIFE_QUERY_RC" -eq 0 ] || return "$LIFE_QUERY_RC"
        [ "$LIFE_DPKG_STATE" != missing ] || return 1
        printf '%s\n' "$LIFE_DPKG_STATE"
    }
    dpkg() { printf 'dpkg %s\n' "$*" >> "$LIFE_TRACE"; return "$LIFE_DPKG_RC"; }
    rm() {
        case "${@: -1}" in
            "$_LIFE_SANDBOX"/*) builtin command rm "$@" ;;
            *) printf 'cleanup %s\n' "$*" >> "$LIFE_TRACE" ;;
        esac
    }
    export -f command mktemp dpkg-deb ar tar dpkg-query dpkg rm
}

_test_thorium_dpkg_deb_without_ar() {
    _life_setup; _life_container_fixtures
    app_install_thorium
    assert_file_contains "$LIFE_TRACE" 'extract -x .*thorium.deb /'
    assert_file_contains "$LIFE_TRACE" 'desktop-register'
    if grep -q '^dpkg ' "$LIFE_TRACE"; then return 1; fi
    [ -z "$(find "$TMPDIR" -mindepth 1 -print -quit)" ]
}
it 'Thorium without ar extracts with dpkg-deb and never registers a package' _test_thorium_dpkg_deb_without_ar

_test_thorium_ar_fallback() {
    _life_setup; _life_container_fixtures
    LIFE_EXTRACTOR=ar
    app_install_thorium
    assert_file_contains "$LIFE_TRACE" 'ar x .*thorium.deb'
    assert_file_contains "$LIFE_TRACE" 'tar -xf ./data.tar.xz -C /'
    assert_file_contains "$LIFE_TRACE" 'desktop-register'
    if grep -q '^dpkg ' "$LIFE_TRACE"; then return 1; fi
}
it 'Thorium supports ar-only distros without package registration' _test_thorium_ar_fallback

_test_thorium_extract_failure() {
    _life_setup; _life_container_fixtures
    LIFE_EXTRACT_RC=42
    if app_install_thorium; then return 1; fi
    if grep -q desktop-register "$LIFE_TRACE"; then return 1; fi
    [ -z "$(find "$TMPDIR" -mindepth 1 -print -quit)" ]
}
it 'Thorium extraction failure cleans staging and keeps the launcher absent' _test_thorium_extract_failure

_test_thorium_registered_remove() {
    _life_setup; _life_container_fixtures
    app_remove_thorium
    assert_file_contains "$LIFE_TRACE" 'query -W -f=${db:Status-Status} thorium-browser'
    assert_file_contains "$LIFE_TRACE" 'dpkg --purge thorium-browser'
    assert_file_contains "$LIFE_TRACE" 'cleanup -rf /opt/chromium.org/thorium'
    assert_file_contains "$LIFE_TRACE" 'desktop-remove'
}
it 'Thorium removal purges registrations left by older dpkg installs' _test_thorium_registered_remove

_test_thorium_purge_failure() {
    _life_setup; _life_container_fixtures
    LIFE_DPKG_RC=42
    if app_remove_thorium; then return 1; fi
    if grep -qE '^(cleanup|desktop-remove)' "$LIFE_TRACE"; then return 1; fi
}
it 'Thorium purge failure preserves package files and launcher' _test_thorium_purge_failure

_test_thorium_query_failure() {
    _life_setup; _life_container_fixtures
    LIFE_QUERY_RC=2
    if app_remove_thorium; then return 1; fi
    if grep -qE '^(dpkg |cleanup|desktop-remove)' "$LIFE_TRACE"; then return 1; fi
}
it 'Thorium package-state query failure preserves package files and launcher' _test_thorium_query_failure

_test_thorium_unregistered_remove() {
    _life_setup; _life_container_fixtures
    LIFE_DPKG_STATE=missing
    app_remove_thorium
    if grep -q '^dpkg ' "$LIFE_TRACE"; then return 1; fi
    assert_file_contains "$LIFE_TRACE" 'desktop-remove'
}
it 'Thorium extraction-only removal skips dpkg and clears its launcher' _test_thorium_unregistered_remove

_life_chroot_fixture() {
    _life_setup
    printf binary > "$PREFIX/bin/chroot-ng"
    chmod +x "$PREFIX/bin/chroot-ng"
}

_test_chroot_selection_reset() {
    _life_chroot_fixture
    local config="$HOME/.config/termux-xfce/config" setting
    for setting in 'PRUN_RUNTIME="chroot-ng"' "PRUN_RUNTIME='chroot-ng'" 'export PRUN_RUNTIME=chroot-ng # selected'; do
        printf '%s\nPROOT_DISTRO=ubuntu\n# PRUN_RUNTIME=chroot-ng\n' "$setting" > "$config"
        chmod 640 "$config"
        PRUN_RUNTIME=chroot-ng
        app_remove_chroot_ng
        assert_eq proot "$PRUN_RUNTIME"
        assert_eq proot "$(unset PRUN_RUNTIME; source "$config"; printf '%s' "$PRUN_RUNTIME")"
        assert_file_contains "$config" '^PROOT_DISTRO=ubuntu$'
        assert_file_contains "$config" '^# PRUN_RUNTIME=chroot-ng$'
        assert_eq 640 "$(stat -c %a "$config")"
        [ ! -e "$PREFIX/bin/chroot-ng" ]
    done
}
it 'chroot-ng removal returns quoted and exported config selections to proot' _test_chroot_selection_reset

_test_chroot_other_config_preserved() {
    _life_chroot_fixture
    local config="$HOME/.config/termux-xfce/config"
    printf 'PRUN_RUNTIME=proot\nCUSTOM="chroot-ng"\n' > "$config"
    cp "$config" "$HOME/original-config"
    app_remove_chroot_ng
    cmp "$HOME/original-config" "$config"
}
it 'chroot-ng removal preserves unrelated settings and existing proot selections' _test_chroot_other_config_preserved

_test_chroot_config_failure_keeps_binary() {
    _life_chroot_fixture
    local config="$HOME/.config/termux-xfce/config"
    printf 'PRUN_RUNTIME="chroot-ng"\n' > "$config"
    cp "$config" "$HOME/original-config"
    sed() { printf partial; return 42; }
    if app_remove_chroot_ng; then return 1; fi
    cmp "$HOME/original-config" "$config"
    [ -x "$PREFIX/bin/chroot-ng" ]
    if compgen -G "${config}.*" >/dev/null; then return 1; fi
}
it 'chroot-ng config write failure preserves the selection and runtime binary' _test_chroot_config_failure_keeps_binary

print_results
