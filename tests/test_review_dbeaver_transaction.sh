#!/data/data/com.termux/files/usr/bin/bash
# Exercise the real installer snippet with every absolute path redirected to fixtures.
_DB_REVIEW_ROOT="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
_DB_REVIEW_BASH="$BASH"
source "$_DB_REVIEW_ROOT/tests/framework.sh"

_db_setup() {
    _DB_SB=$(make_sandbox)
    trap 'cleanup_sandbox "$_DB_SB"' EXIT
    export DB_SB="$_DB_SB" DB_DOWNLOAD_FAIL=false DB_MOVE_FAIL=false DB_LINK_FAIL=false DB_LINK_MOVE_FAIL=false
    mkdir -p "$DB_SB/opt/dbeaver" "$DB_SB/usr/bin" "$DB_SB/tmp" "$DB_SB/archive/dbeaver"
    printf old > "$DB_SB/opt/dbeaver/dbeaver"
    chmod +x "$DB_SB/opt/dbeaver/dbeaver"
    ln -s "$DB_SB/opt/dbeaver/dbeaver" "$DB_SB/usr/bin/dbeaver"
    printf new > "$DB_SB/archive/dbeaver/dbeaver"
    chmod +x "$DB_SB/archive/dbeaver/dbeaver"
    command tar -czf "$DB_SB/archive.tar.gz" -C "$DB_SB/archive" dbeaver
    source "$_DB_REVIEW_ROOT/lib/fetch.sh"
    source "$_DB_REVIEW_ROOT/domain/installers/dbeaver.sh"
    has_proot_distro() { return 0; }
    proot_pkg_update() { return 0; }
    desktop_register_proot() { touch "$DB_SB/registered"; }
    fetch_verified() {
        [ "$DB_DOWNLOAD_FAIL" = false ] || return 42
        cp "$DB_SB/archive.tar.gz" "$2"
    }
    sudo() { "$@"; }
    mv() {
        local source="${@: -2:1}" target="${@: -1}"
        if [ "$DB_MOVE_FAIL" = true ] &&
           [[ "$source" = */dbeaver ]] &&
           { [ "$target" = "$DB_SB/opt/dbeaver" ] || [ "$target" = "$DB_SB/opt/" ]; }; then
            return 42
        fi
        if [ "$DB_LINK_MOVE_FAIL" = true ] && [[ "$source" = */new ]] &&
           [ "$target" = "$DB_SB/usr/bin/dbeaver" ]; then
            return 42
        fi
        command mv "$@"
    }
    ln() { [ "$DB_LINK_FAIL" = false ] || return 42; command ln "$@"; }
    export -f sudo mv ln
    proot_exec() {
        [ "$1" != sudo ] || shift
        [ "$1" = bash ] && [ "$2" = -c ] || return 98
        local snippet="$3"
        shift 3
        snippet="${snippet//\/tmp/$DB_SB/tmp}"
        snippet="${snippet//\/opt\//$DB_SB/opt/}"
        snippet="${snippet//\/usr\/bin\//$DB_SB/usr/bin/}"
        "$_DB_REVIEW_BASH" -c "$snippet" "$@"
    }
}

_db_assert_preserved() {
    assert_eq old "$(cat "$DB_SB/opt/dbeaver/dbeaver")"
    assert_eq old "$(cat "$DB_SB/usr/bin/dbeaver")"
    [ ! -e "$DB_SB/registered" ]
}

_db_download_failure() {
    _db_setup
    export DB_DOWNLOAD_FAIL=true
    if app_install_dbeaver; then return 1; fi
    _db_assert_preserved
}
it 'DBeaver download failure preserves the previous installation' _db_download_failure

_db_invalid_archive() {
    _db_setup
    command rm "$DB_SB/archive/dbeaver/dbeaver"
    command tar -czf "$DB_SB/archive.tar.gz" -C "$DB_SB/archive" dbeaver
    if app_install_dbeaver; then return 1; fi
    _db_assert_preserved
}
it 'DBeaver validates the extracted executable before replacing an installation' _db_invalid_archive

_db_publish_failure() {
    _db_setup
    export DB_MOVE_FAIL=true
    if app_install_dbeaver; then return 1; fi
    _db_assert_preserved
    [ -z "$(find "$DB_SB/opt" -maxdepth 1 -name '.dbeaver-install.*' -print -quit)" ]
}
it 'DBeaver publication failure restores the previous installation and removes staging' _db_publish_failure

_db_link_failure() {
    _db_setup
    export DB_LINK_FAIL=true
    if app_install_dbeaver; then return 1; fi
    _db_assert_preserved
}
it 'DBeaver link failure leaves the previous executable usable' _db_link_failure

_db_success() {
    _db_setup
    app_install_dbeaver
    assert_eq new "$(cat "$DB_SB/opt/dbeaver/dbeaver")"
    assert_eq new "$(cat "$DB_SB/usr/bin/dbeaver")"
    assert_file_exists "$DB_SB/registered"
    [ -z "$(find "$DB_SB/opt" -maxdepth 1 -name '.dbeaver-install.*' -print -quit)" ]
}
it 'DBeaver replaces a validated installation and registers its launcher' _db_success

_db_first_install_failure() {
    _db_setup
    command rm -rf "$DB_SB/opt/dbeaver"
    command rm "$DB_SB/usr/bin/dbeaver"
    export DB_MOVE_FAIL=true
    if app_install_dbeaver; then return 1; fi
    [ ! -e "$DB_SB/opt/dbeaver" ]
    [ ! -L "$DB_SB/usr/bin/dbeaver" ]
    [ ! -e "$DB_SB/registered" ]
}
it 'DBeaver failed first publication leaves no partial installation' _db_first_install_failure

_db_link_publish_failure() {
    _db_setup
    export DB_LINK_MOVE_FAIL=true
    if app_install_dbeaver; then return 1; fi
    _db_assert_preserved
    [ -z "$(find "$DB_SB/usr/bin" -maxdepth 1 -name '.dbeaver-link.*' -print -quit)" ]
}
it 'DBeaver link publication failure restores both the executable and link' _db_link_publish_failure

_db_custom_link_failure() {
    _db_setup
    command rm "$DB_SB/usr/bin/dbeaver"
    printf custom > "$DB_SB/usr/bin/dbeaver"
    chmod 751 "$DB_SB/usr/bin/dbeaver"
    export DB_LINK_MOVE_FAIL=true
    if app_install_dbeaver; then return 1; fi
    assert_eq old "$(cat "$DB_SB/opt/dbeaver/dbeaver")"
    assert_eq custom "$(cat "$DB_SB/usr/bin/dbeaver")"
    assert_eq 751 "$(stat -c %a "$DB_SB/usr/bin/dbeaver")"
    [ ! -e "$DB_SB/registered" ]
}
it 'DBeaver failed replacement preserves a custom command and its permissions' _db_custom_link_failure

print_results
