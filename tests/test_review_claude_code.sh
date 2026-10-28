#!/data/data/com.termux/files/usr/bin/bash
_CLAUDE_REVIEW_ROOT="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
source "$_CLAUDE_REVIEW_ROOT/tests/framework.sh"
source "$_CLAUDE_REVIEW_ROOT/tests/mocks.sh"

_claude_review_setup() {
    setup_fs_sandbox "$1"
    source "$_CLAUDE_REVIEW_ROOT/domain/installers/claude_code.sh"
    mkdir -p "$CLAUDE_CODE_PREFIX" "$PREFIX/glibc/bin"
    ln -s "$BASH" "$PREFIX/bin/bash"
    _CLAUDE_REVIEW_SANDBOX="$1"
    trap 'unset LD_PRELOAD; cleanup_sandbox "$_CLAUDE_REVIEW_SANDBOX"' EXIT
}

_test_rollback_preserves_old_inode() {
    local sb; sb=$(make_sandbox); _claude_review_setup "$sb"
    echo 'active binary' > "$CLAUDE_CODE_PREFIX/claude"
    local active_fd active_content
    exec {active_fd}< "$CLAUDE_CODE_PREFIX/claude"
    echo 'backup binary' > "$CLAUDE_CODE_PREFIX/claude.bak.v1.0"
    app_rollback_claude_code 1.0
    IFS= read -r active_content <&"$active_fd"
    exec {active_fd}<&-
    assert_eq 'active binary' "$active_content"
    assert_eq 'backup binary' "$(cat "$CLAUDE_CODE_PREFIX/claude")"
    [ -x "$CLAUDE_CODE_PREFIX/claude" ]
    cleanup_sandbox "$sb"
}
it 'Claude rollback replaces the file while preserving the inode used by an active process (#3)' _test_rollback_preserves_old_inode

_claude_review_linker() {
    {
        printf '#!%s\n' "$BASH"
        cat <<'STUB'
[ "${LD_PRELOAD-unset}" = unset ] || exit 98
printf '%s\n' "$@" > "$HOME/linker-args"
exit "${CLAUDE_REVIEW_LINKER_RC:-0}"
STUB
    } > "$PREFIX/glibc/bin/ld.so"
    chmod +x "$PREFIX/glibc/bin/ld.so"
}

_test_smoke_preload_is_scoped() {
    local sb; sb=$(make_sandbox); _claude_review_setup "$sb"
    _claude_code_install_wrapper
    _claude_review_linker
    LD_PRELOAD=unusable-bionic-hook
    _claude_code_smoke_check
    assert_eq unusable-bionic-hook "$LD_PRELOAD"
    unset LD_PRELOAD
    assert_eq "$CLAUDE_CODE_PREFIX/claude"$'\n--version' "$(cat "$HOME/linker-args")"
}
it 'Claude smoke runs the real wrapper and preserves the caller preload' _test_smoke_preload_is_scoped

_test_wrapper_uses_native_linker_path() {
    local sb; sb=$(make_sandbox); _claude_review_setup "$sb"
    _claude_code_install_wrapper
    _claude_review_linker
    PATH=/nonexistent "$CLAUDE_CODE_BIN_PATH" 'argument with spaces' '%literal'
    assert_eq "$CLAUDE_CODE_PREFIX/claude"$'\nargument with spaces\n%literal' \
        "$(cat "$HOME/linker-args")"
}
it 'Claude wrapper starts the absolute ld.so path and preserves arguments' _test_wrapper_uses_native_linker_path

_test_smoke_rejects_broken_wrapper() {
    local sb; sb=$(make_sandbox); _claude_review_setup "$sb"
    _claude_code_install_wrapper
    _claude_review_linker
    export CLAUDE_REVIEW_LINKER_RC=42
    if _claude_code_smoke_check; then return 1; fi
    unset CLAUDE_REVIEW_LINKER_RC
    printf '#!%s\nexit 42\n' "$BASH" > "$CLAUDE_CODE_BIN_PATH"
    if _claude_code_smoke_check; then return 1; fi
}
it 'Claude smoke rejects failures in both the installed wrapper and linker' _test_smoke_rejects_broken_wrapper

_claude_review_existing_wrapper() {
    printf '#!%s\nprintf existing-wrapper\\n\n' "$BASH" > "$CLAUDE_CODE_BIN_PATH"
    chmod +x "$CLAUDE_CODE_BIN_PATH"
    cp -p "$CLAUDE_CODE_BIN_PATH" "$HOME/original-wrapper"
}

_claude_review_assert_wrapper_intact() {
    cmp "$HOME/original-wrapper" "$CLAUDE_CODE_BIN_PATH"
    [ -x "$CLAUDE_CODE_BIN_PATH" ]
    if compgen -G "${CLAUDE_CODE_BIN_PATH}.*" >/dev/null; then return 1; fi
}

_test_wrapper_failure_preserves_existing() {
    local sb; sb=$(make_sandbox); _claude_review_setup "$sb"
    _claude_review_existing_wrapper
    cat() { printf partial; return 42; }
    if _claude_code_install_wrapper; then return 1; fi
    unset -f cat
    _claude_review_assert_wrapper_intact
    chmod() { return 42; }
    if _claude_code_install_wrapper; then return 1; fi
    unset -f chmod
    _claude_review_assert_wrapper_intact
    mv() { return 42; }
    if _claude_code_install_wrapper; then return 1; fi
    unset -f mv
    _claude_review_assert_wrapper_intact
}
it 'failed wrapper write, chmod, and rename preserve the executable and clean staging' _test_wrapper_failure_preserves_existing

_test_upgrade_wrapper_failure_restores_binary() {
    local sb; sb=$(make_sandbox); _claude_review_setup "$sb"
    _claude_review_existing_wrapper
    printf original > "$CLAUDE_CODE_PREFIX/claude"
    chmod +x "$CLAUDE_CODE_PREFIX/claude"
    printf original-metadata > "$CLAUDE_CODE_PREFIX/package.json"
    printf 1.0 > "$CLAUDE_CODE_VERSION_FILE"
    _claude_code_fetch_latest_version() { printf 2.0; }
    _claude_code_download_native() {
        printf new > "$CLAUDE_CODE_PREFIX/claude"
        printf 2.0 > "$CLAUDE_CODE_VERSION_FILE"
    }
    # Full-disk style failure affects both upgrade and rollback wrapper writes.
    cat() {
        if [ "$#" -gt 0 ]; then command cat "$@"; else printf partial; return 42; fi
    }
    if app_upgrade_claude_code; then return 1; fi
    unset -f cat
    _claude_review_assert_wrapper_intact
    assert_eq original "$(cat "$CLAUDE_CODE_PREFIX/claude")"
    assert_eq original "$(cat "$CLAUDE_CODE_PREFIX/claude.bak.v1.0")"
    assert_eq original-metadata "$(cat "$CLAUDE_CODE_PREFIX/package.json")"
    assert_eq 1.0 "$(cat "$CLAUDE_CODE_VERSION_FILE")"
}
it 'upgrade wrapper failure returns failure and restores the binary and version' _test_upgrade_wrapper_failure_restores_binary

_test_rollback_wrapper_failure_propagates() {
    local sb; sb=$(make_sandbox); _claude_review_setup "$sb"
    _claude_review_existing_wrapper
    printf original > "$CLAUDE_CODE_PREFIX/claude.bak.v1.0"
    cat() { printf partial; return 42; }
    if app_rollback_claude_code 1.0 > "$HOME/rollback.log"; then return 1; fi
    unset -f cat
    _claude_review_assert_wrapper_intact
    assert_eq original "$(cat "$CLAUDE_CODE_PREFIX/claude")"
    assert_eq 1.0 "$(cat "$CLAUDE_CODE_VERSION_FILE")"
    [ ! -s "$HOME/rollback.log" ]
}
it 'rollback wrapper failure returns failure without a success message' _test_rollback_wrapper_failure_propagates

print_results
