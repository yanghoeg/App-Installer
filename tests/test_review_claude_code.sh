#!/data/data/com.termux/files/usr/bin/bash
_CLAUDE_REVIEW_ROOT="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
source "$_CLAUDE_REVIEW_ROOT/tests/framework.sh"
source "$_CLAUDE_REVIEW_ROOT/tests/mocks.sh"

_claude_review_setup() {
    setup_fs_sandbox "$1"
    source "$_CLAUDE_REVIEW_ROOT/domain/installers/claude_code.sh"
    mkdir -p "$CLAUDE_CODE_PREFIX"
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

_test_smoke_preload_is_scoped() {
    local sb; sb=$(make_sandbox); _claude_review_setup "$sb"
    LD_PRELOAD=unusable-bionic-hook
    RUNNING_IN_GLIBC_RUNNER=true
    grun() { [ "${LD_PRELOAD-unset}" = unset ] && [ "$2" = --version ]; }
    _claude_code_smoke_check
    assert_eq unusable-bionic-hook "$LD_PRELOAD"
    unset LD_PRELOAD
    cleanup_sandbox "$sb"
}
it 'Claude smoke clears inherited preload without changing the caller environment (#4)' _test_smoke_preload_is_scoped

_test_wrapper_uses_native_grun_path() {
    local sb; sb=$(make_sandbox); _claude_review_setup "$sb"
    _claude_code_install_wrapper
    cat > "$PREFIX/bin/grun" <<'STUB'
#!/data/data/com.termux/files/usr/bin/bash
[ "${LD_PRELOAD-unset}" = unset ] || exit 1
printf '%s\n' "$@"
STUB
    chmod +x "$PREFIX/bin/grun"
    assert_eq "$CLAUDE_CODE_PREFIX/claude"$'\nargument with spaces' \
        "$(LD_PRELOAD= PATH=/nonexistent /data/data/com.termux/files/usr/bin/bash "$CLAUDE_CODE_BIN_PATH" 'argument with spaces')"
    cleanup_sandbox "$sb"
}
it 'Claude wrapper starts the native grun path and preserves arguments (#4)' _test_wrapper_uses_native_grun_path

print_results
