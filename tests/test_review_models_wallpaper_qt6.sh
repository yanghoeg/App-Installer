#!/data/data/com.termux/files/usr/bin/bash
# Isolated regressions for the Qt6, wallpaper and interrupted-model findings.
_FEATURE_APP_DIR="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
source "$_FEATURE_APP_DIR/tests/framework.sh"

_feature_sandbox() {
    _FEATURE_SANDBOX=$(make_sandbox)
    trap 'cleanup_sandbox "$_FEATURE_SANDBOX"' EXIT
    export PREFIX="$_FEATURE_SANDBOX/usr"
    mkdir -p "$PREFIX/bin" "$_FEATURE_SANDBOX/rootfs" "$_FEATURE_SANDBOX/home/models"
    source "$_FEATURE_APP_DIR/domain/installers/korean_proot.sh"
    source "$_FEATURE_APP_DIR/domain/installers/api_wallpaper.sh"
    source "$_FEATURE_APP_DIR/domain/installers/llama_cpp.sh"
    _proot_rootfs() { printf '%s\n' "$_FEATURE_SANDBOX/rootfs"; }
    proot_exec() {
        if [ "$*" = 'dpkg --print-architecture' ]; then printf 'arm64\n'; fi
    }
    _FEATURE_QT_SOURCE="$(_proot_rootfs)/usr/lib/x86_64-linux-gnu/qt6/plugins/platforminputcontexts/libqt6im-nimf.so"
    _FEATURE_QT_TARGET="$(_proot_rootfs)/usr/lib/aarch64-linux-gnu/qt6/plugins/platforminputcontexts/libqt6im-nimf.so"
}

_qt6_existing_nimf_is_repaired() {
    _feature_sandbox
    mkdir -p "${_FEATURE_QT_SOURCE%/*}"
    printf 'arm64 plugin\n' > "$_FEATURE_QT_SOURCE"
    _korean_proot_install_pkgs() { return 0; }
    proot_pkg_install_deb_url() { echo 'existing Nimf must not be downloaded' >&2; return 99; }
    _korean_proot_write_locale() { return 0; }
    _korean_proot_install_ubuntu
    _korean_proot_install_ubuntu
    [ -L "$_FEATURE_QT_TARGET" ]
    assert_eq 'arm64 plugin' "$(cat "$_FEATURE_QT_TARGET")"
    _korean_proot_remove_ubuntu_qt6_link
    [ ! -L "$_FEATURE_QT_TARGET" ]
    assert_file_exists "$_FEATURE_QT_SOURCE"
}
it 'Ubuntu repairs existing Nimf Qt6 once and removes only its managed link' _qt6_existing_nimf_is_repaired

_qt6_native_plugin_is_preserved() {
    _feature_sandbox
    mkdir -p "${_FEATURE_QT_SOURCE%/*}" "${_FEATURE_QT_TARGET%/*}"
    printf 'legacy\n' > "$_FEATURE_QT_SOURCE"
    printf 'native\n' > "$_FEATURE_QT_TARGET"
    _korean_proot_fix_ubuntu_qt6
    _korean_proot_remove_ubuntu_qt6_link
    assert_eq native "$(cat "$_FEATURE_QT_TARGET")"
}
it 'the Qt6 correction preserves a native ARM64 plugin from a fixed package' _qt6_native_plugin_is_preserved

_qt6_other_arch_is_preserved() {
    _feature_sandbox
    mkdir -p "${_FEATURE_QT_SOURCE%/*}"
    printf 'x86 plugin\n' > "$_FEATURE_QT_SOURCE"
    proot_exec() { printf 'amd64\n'; }
    _korean_proot_fix_ubuntu_qt6
    [ ! -e "$_FEATURE_QT_TARGET" ]
}
it 'the Qt6 correction does not expose an amd64 plugin as ARM64' _qt6_other_arch_is_preserved

_wallpaper_setup() {
    _feature_sandbox
    export FEATURE_WP_LIST="$_FEATURE_SANDBOX/properties"
    export FEATURE_WP_FILES="$_FEATURE_SANDBOX/images"
    export FEATURE_WP_LOG="$_FEATURE_SANDBOX/wallpaper.log"
    export FEATURE_WP_WORKSPACE=0 FEATURE_WP_SINGLE=false FEATURE_WP_SINGLE_NUMBER=0
    mkdir -p "$FEATURE_WP_FILES"
    cat > "$PREFIX/bin/xfconf-query" <<'STUB'
#!/data/data/com.termux/files/usr/bin/bash
if [ "$*" = '-c xfce4-desktop -l' ]; then cat "$FEATURE_WP_LIST"; exit; fi
case "${4:-}" in
    /backdrop/single-workspace-mode) printf '%s\n' "$FEATURE_WP_SINGLE" ;;
    /backdrop/single-workspace-number) printf '%s\n' "$FEATURE_WP_SINGLE_NUMBER" ;;
    *) key=${4##*/monitor}; key=${key%/last-image}; key=${key//\//_}
       [ -f "$FEATURE_WP_FILES/$key" ] || exit 1
       printf '%s\n' "$FEATURE_WP_FILES/$key" ;;
esac
STUB
    cat > "$PREFIX/bin/xprop" <<'STUB'
#!/data/data/com.termux/files/usr/bin/bash
printf '_NET_CURRENT_DESKTOP(CARDINAL) = %s\n' "$FEATURE_WP_WORKSPACE"
STUB
    cat > "$PREFIX/bin/termux-wallpaper" <<'STUB'
#!/data/data/com.termux/files/usr/bin/bash
printf '%s\n' "$*" >> "$FEATURE_WP_LOG"
STUB
    cat > "$PREFIX/bin/yad" <<'STUB'
#!/data/data/com.termux/files/usr/bin/bash
exit 0
STUB
    chmod +x "$PREFIX/bin/xfconf-query" "$PREFIX/bin/xprop" "$PREFIX/bin/termux-wallpaper" "$PREFIX/bin/yad"
    app_install_api_wallpaper
}

_wallpaper_deployed_monitor() {
    _wallpaper_setup
    printf '/backdrop/screen0/monitorscreen/workspace0/last-image\n' > "$FEATURE_WP_LIST"
    touch "$FEATURE_WP_FILES/screen_workspace0"
    env PATH="$PREFIX/bin:$PATH" bash "$_WALLSYNC_SCRIPT"
    assert_eq "-f $FEATURE_WP_FILES/screen_workspace0" "$(cat "$FEATURE_WP_LOG")"
}
it 'wallpaper sync finds the deployed monitorscreen property' _wallpaper_deployed_monitor

_wallpaper_vnc_current_workspace() {
    _wallpaper_setup
    export FEATURE_WP_WORKSPACE=2
    printf '%s\n' /backdrop/screen0/monitorVNC-0/workspace0/last-image /backdrop/screen0/monitorVNC-0/workspace2/last-image > "$FEATURE_WP_LIST"
    touch "$FEATURE_WP_FILES/VNC-0_workspace0" "$FEATURE_WP_FILES/VNC-0_workspace2"
    env PATH="$PREFIX/bin:$PATH" bash "$_WALLSYNC_SCRIPT"
    assert_eq "-f $FEATURE_WP_FILES/VNC-0_workspace2" "$(cat "$FEATURE_WP_LOG")"
}
it 'wallpaper sync discovers VNC monitors and prefers the current workspace' _wallpaper_vnc_current_workspace

_wallpaper_single_workspace_and_fallback() {
    _wallpaper_setup
    export FEATURE_WP_WORKSPACE=2 FEATURE_WP_SINGLE=true FEATURE_WP_SINGLE_NUMBER=1
    printf '%s\n' /backdrop/screen0/monitorVNC-0/workspace2/last-image /backdrop/screen0/monitorVNC-0/workspace1/last-image > "$FEATURE_WP_LIST"
    touch "$FEATURE_WP_FILES/VNC-0_workspace1" "$FEATURE_WP_FILES/VNC-0_workspace2"
    env PATH="$PREFIX/bin:$PATH" bash "$_WALLSYNC_SCRIPT"
    assert_eq "-f $FEATURE_WP_FILES/VNC-0_workspace1" "$(cat "$FEATURE_WP_LOG")"
    rm "$FEATURE_WP_FILES/VNC-0_workspace1" "$FEATURE_WP_LOG"
    env PATH="$PREFIX/bin:$PATH" bash "$_WALLSYNC_SCRIPT"
    assert_eq "-f $FEATURE_WP_FILES/VNC-0_workspace2" "$(cat "$FEATURE_WP_LOG")"
}
it 'wallpaper sync respects single-workspace mode and skips missing images' _wallpaper_single_workspace_and_fallback

_wallpaper_missing_returns_failure() {
    _wallpaper_setup
    printf '/backdrop/screen0/monitorVNC-0/workspace0/last-image\n' > "$FEATURE_WP_LIST"
    if env PATH="$PREFIX/bin:$PATH" bash "$_WALLSYNC_SCRIPT"; then return 1; fi
    [ ! -e "$FEATURE_WP_LOG" ]
}
it 'wallpaper sync fails without sending a nonexistent image to Android' _wallpaper_missing_returns_failure

_model_setup() {
    _feature_sandbox
    export FEATURE_MODEL_HOME="$_FEATURE_SANDBOX/home"
    export FEATURE_MODEL_OUT="$FEATURE_MODEL_HOME/models/qwen2.5-0.5b-instruct-q5_k_m.gguf"
    export FEATURE_MODEL_LOG="$_FEATURE_SANDBOX/curl.log"
    export FEATURE_MODEL_FAIL=false FEATURE_MODEL_HEAD_FAIL=false FEATURE_MODEL_HEAD_SIZE=8
    export FEATURE_MODEL_CONTENT=abcdefgh FEATURE_MODEL_SUFFIX=efgh FEATURE_MODEL_CDN_SIZE=unknown
    FEATURE_MODEL_HEAD_SHA=$(printf abcdefgh | sha256sum)
    export FEATURE_MODEL_HEAD_SHA=${FEATURE_MODEL_HEAD_SHA%% *}
    cat > "$PREFIX/bin/curl" <<'STUB'
#!/data/data/com.termux/files/usr/bin/bash
printf '%s\n' "$*" >> "$FEATURE_MODEL_LOG"
if [ "$1" = '-fsIL' ]; then
    [ "$FEATURE_MODEL_HEAD_FAIL" = false ] || exit 22
    printf 'HTTP/1.1 302 Found\r\nContent-Length: 99\r\n'
    [ "$FEATURE_MODEL_HEAD_SIZE" = unknown ] || printf 'x-linked-size: %s\r\n' "$FEATURE_MODEL_HEAD_SIZE"
    [ "$FEATURE_MODEL_HEAD_SHA" = unknown ] || printf 'x-linked-etag: "%s"\r\n' "$FEATURE_MODEL_HEAD_SHA"
    printf '\r\nHTTP/2 200\r\n'
    [ "$FEATURE_MODEL_CDN_SIZE" = unknown ] || printf 'content-length: %s\r\n' "$FEATURE_MODEL_CDN_SIZE"
    printf '\r\n'
    exit 0
fi
[ "$1 $2 $3 $4" = '-fL -C - -o' ] || exit 90
[ "$5" = "$FEATURE_MODEL_OUT.part" ] || exit 91
if [ "$FEATURE_MODEL_FAIL" = true ]; then
    printf 'abcd' > "$5"
    exit 18
fi
if [ -f "$5" ]; then
    [ "$(cat "$5")" = abcd ] || exit 92
    printf '%s' "$FEATURE_MODEL_SUFFIX" >> "$5"
else
    printf '%s' "$FEATURE_MODEL_CONTENT" > "$5"
fi
STUB
    chmod +x "$PREFIX/bin/curl"
    _llama_write_model_get
}

_model_run() {
    env HOME="$FEATURE_MODEL_HOME" PATH="$PREFIX/bin:$PATH" bash "$_LLAMA_MODEL_GET_BIN" 0.5b > "$_FEATURE_SANDBOX/model.stdout" 2> "$_FEATURE_SANDBOX/model.stderr"
}

_model_failure_then_resume() {
    _model_setup
    export FEATURE_MODEL_FAIL=true
    if _model_run; then return 1; fi
    [ ! -e "$FEATURE_MODEL_OUT" ]
    assert_eq abcd "$(cat "$FEATURE_MODEL_OUT.part")"
    export FEATURE_MODEL_FAIL=false
    _model_run
    assert_eq abcdefgh "$(cat "$FEATURE_MODEL_OUT")"
    [ ! -e "$FEATURE_MODEL_OUT.part" ]
}
it 'a failed model download remains .part and resumes before final rename' _model_failure_then_resume

_model_legacy_partial_resumes() {
    _model_setup
    printf abcd > "$FEATURE_MODEL_OUT"
    _model_run
    assert_eq abcdefgh "$(cat "$FEATURE_MODEL_OUT")"
    assert_file_contains "$FEATURE_MODEL_LOG" 'fsIL'
    [ ! -e "$FEATURE_MODEL_OUT.part" ]
}
it 'an interrupted legacy final file is copied and its resumed contents are SHA256-verified' _model_legacy_partial_resumes

_model_complete_is_preserved() {
    _model_setup
    printf abcdefgh > "$FEATURE_MODEL_OUT"
    _model_run
    assert_eq abcdefgh "$(cat "$FEATURE_MODEL_OUT")"
    assert_eq 1 "$(wc -l < "$FEATURE_MODEL_LOG" | tr -d '[:space:]')"
    assert_file_exists "$FEATURE_MODEL_OUT.complete"
    rm "$FEATURE_MODEL_LOG"
    export FEATURE_MODEL_HEAD_FAIL=true FEATURE_MODEL_FAIL=true
    _model_run
    [ ! -e "$FEATURE_MODEL_LOG" ]
}
it 'a complete legacy model is marked after HEAD verification and then works offline' _model_complete_is_preserved

_model_completed_download_works_offline() {
    _model_setup
    _model_run
    assert_eq abcdefgh "$(cat "$FEATURE_MODEL_OUT")"
    assert_eq 8 "$(sed -n '2p' "$FEATURE_MODEL_OUT.complete")"
    [ "$(wc -l < "$FEATURE_MODEL_OUT.complete" | tr -d '[:space:]')" -eq 3 ]
    assert_eq "$FEATURE_MODEL_HEAD_SHA" "$(sed -n '3p' "$FEATURE_MODEL_OUT.complete")"
    if compgen -G "$FEATURE_MODEL_OUT.complete.tmp.*" > /dev/null; then return 1; fi
    rm "$FEATURE_MODEL_LOG"
    export FEATURE_MODEL_HEAD_FAIL=true FEATURE_MODEL_FAIL=true
    _model_run
    [ ! -e "$FEATURE_MODEL_LOG" ]
    assert_eq abcdefgh "$(cat "$FEATURE_MODEL_OUT")"
}
it 'a successful new download receives an atomic marker and reruns without curl offline' _model_completed_download_works_offline

_model_marker_size_mismatch_preserves_file() {
    _model_setup
    _model_run
    printf abcd > "$FEATURE_MODEL_OUT"
    rm "$FEATURE_MODEL_LOG"
    if _model_run; then return 1; fi
    assert_eq abcd "$(cat "$FEATURE_MODEL_OUT")"
    assert_eq 8 "$(sed -n '2p' "$FEATURE_MODEL_OUT.complete")"
    [ ! -e "$FEATURE_MODEL_LOG" ]
    [ ! -e "$FEATURE_MODEL_OUT.part" ]
}
it 'a changed model size invalidates its marker and preserves the model without claiming success' _model_marker_size_mismatch_preserves_file

_model_unverifiable_is_preserved() {
    _model_setup
    printf abcd > "$FEATURE_MODEL_OUT"
    export FEATURE_MODEL_HEAD_FAIL=true
    if _model_run; then return 1; fi
    assert_eq abcd "$(cat "$FEATURE_MODEL_OUT")"
    export FEATURE_MODEL_HEAD_FAIL=false FEATURE_MODEL_HEAD_SIZE=unknown
    if _model_run; then return 1; fi
    assert_eq abcd "$(cat "$FEATURE_MODEL_OUT")"
    [ ! -e "$FEATURE_MODEL_OUT.part" ]
}
it 'a HEAD failure or missing remote size preserves an existing model and fails clearly' _model_unverifiable_is_preserved

_model_revision_change_is_rejected() {
    _model_setup
    printf abcd > "$FEATURE_MODEL_OUT.part"
    export FEATURE_MODEL_CONTENT=ABCDEFGH FEATURE_MODEL_SUFFIX=EFGH
    FEATURE_MODEL_HEAD_SHA=$(printf ABCDEFGH | sha256sum)
    export FEATURE_MODEL_HEAD_SHA=${FEATURE_MODEL_HEAD_SHA%% *}
    if _model_run; then return 1; fi
    assert_eq abcdEFGH "$(cat "$FEATURE_MODEL_OUT.part")"
    [ ! -e "$FEATURE_MODEL_OUT" ]
    [ ! -e "$FEATURE_MODEL_OUT.complete" ]
    assert_file_contains "$_FEATURE_SANDBOX/model.stderr" 'SHA256'
}
it 'resuming an old prefix after a remote revision change cannot publish mixed model contents' _model_revision_change_is_rejected

_model_same_size_legacy_is_rejected() {
    _model_setup
    printf ABCDEFGH > "$FEATURE_MODEL_OUT"
    if _model_run; then return 1; fi
    assert_eq ABCDEFGH "$(cat "$FEATURE_MODEL_OUT")"
    [ ! -e "$FEATURE_MODEL_OUT.complete" ]
    assert_eq 1 "$(wc -l < "$FEATURE_MODEL_LOG" | tr -d '[:space:]')"
}
it 'a same-size legacy model with different bytes fails SHA256 verification and stays intact' _model_same_size_legacy_is_rejected

_model_missing_sha_is_preserved() {
    _model_setup
    printf abcd > "$FEATURE_MODEL_OUT"
    printf existing > "$FEATURE_MODEL_OUT.part"
    local sha
    for sha in unknown invalid; do
        export FEATURE_MODEL_HEAD_SHA=$sha
        if _model_run; then return 1; fi
        assert_eq abcd "$(cat "$FEATURE_MODEL_OUT")"
        assert_eq existing "$(cat "$FEATURE_MODEL_OUT.part")"
        [ ! -e "$FEATURE_MODEL_OUT.complete" ]
    done
    assert_eq 2 "$(wc -l < "$FEATURE_MODEL_LOG" | tr -d '[:space:]')"
}
it 'missing or invalid SHA256 metadata preserves both files without downloading model contents' _model_missing_sha_is_preserved

_model_legacy_marker_is_reverified() {
    _model_setup
    printf abcdefgh > "$FEATURE_MODEL_OUT"
    printf 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q5_k_m.gguf\n8\n' > "$FEATURE_MODEL_OUT.complete"
    _model_run
    assert_eq 1 "$(wc -l < "$FEATURE_MODEL_LOG" | tr -d '[:space:]')"
    assert_eq "$FEATURE_MODEL_HEAD_SHA" "$(sed -n '3p' "$FEATURE_MODEL_OUT.complete")"
}
it 'an old two-line completion marker requires HEAD and full SHA256 verification before upgrade' _model_legacy_marker_is_reverified

_model_legacy_resume_failure_keeps_original() {
    _model_setup
    printf abcd > "$FEATURE_MODEL_OUT"
    export FEATURE_MODEL_FAIL=true
    if _model_run; then return 1; fi
    assert_eq abcd "$(cat "$FEATURE_MODEL_OUT")"
    assert_eq abcd "$(cat "$FEATURE_MODEL_OUT.part")"
    [ ! -e "$FEATURE_MODEL_OUT.complete" ]
}
it 'a failed legacy resume retains the original OUT while preserving its resumable copy' _model_legacy_resume_failure_keeps_original

_model_copy_failure_keeps_original() {
    _model_setup
    printf abcd > "$FEATURE_MODEL_OUT"
    cat > "$PREFIX/bin/cp" <<'STUB'
#!/data/data/com.termux/files/usr/bin/bash
printf ab > "$2"
exit 1
STUB
    chmod +x "$PREFIX/bin/cp"
    if _model_run; then return 1; fi
    assert_eq abcd "$(cat "$FEATURE_MODEL_OUT")"
    assert_eq ab "$(cat "$FEATURE_MODEL_OUT.part")"
    assert_eq 1 "$(wc -l < "$FEATURE_MODEL_LOG" | tr -d '[:space:]')"
}
it 'a failed copy for legacy resume leaves the original OUT intact and never downloads' _model_copy_failure_keeps_original

_model_cached_same_size_change_is_rejected() {
    _model_setup
    _model_run
    printf ABCDEFGH > "$FEATURE_MODEL_OUT"
    rm "$FEATURE_MODEL_LOG"
    if _model_run; then return 1; fi
    assert_eq ABCDEFGH "$(cat "$FEATURE_MODEL_OUT")"
    [ ! -e "$FEATURE_MODEL_LOG" ]
}
it 'verified offline reuse detects later same-size model changes against its stored SHA256' _model_cached_same_size_change_is_rejected

_model_conflict_is_preserved() {
    _model_setup
    printf abcd > "$FEATURE_MODEL_OUT"
    printf other > "$FEATURE_MODEL_OUT.part"
    if _model_run; then return 1; fi
    assert_eq abcd "$(cat "$FEATURE_MODEL_OUT")"
    assert_eq other "$(cat "$FEATURE_MODEL_OUT.part")"
}
it 'a legacy partial model and a separate .part file are both preserved' _model_conflict_is_preserved

_llama_generation_failure_keeps_helpers() {
    _feature_sandbox
    printf 'previous GPU helper\n' > "$_LLAMA_GPU_BIN"
    printf 'previous model helper\n' > "$_LLAMA_MODEL_GET_BIN"
    local generator
    for generator in _llama_write_gpu_launcher _llama_write_model_get; do
        if (
            cat() { printf 'incomplete helper\n'; return 1; }
            "$generator"
        ); then return 1; fi
        assert_eq 'previous GPU helper' "$(cat "$_LLAMA_GPU_BIN")"
        assert_eq 'previous model helper' "$(cat "$_LLAMA_MODEL_GET_BIN")"
    done
    if (
        cat() { printf 'incomplete helper\n'; return 1; }
        termux_pkg_install() { return 0; }
        app_install_llama_cpp
    ); then return 1; fi
    assert_eq 'previous GPU helper' "$(cat "$_LLAMA_GPU_BIN")"
    assert_eq 'previous model helper' "$(cat "$_LLAMA_MODEL_GET_BIN")"
    if compgen -G "$PREFIX/bin/llama-*.tmp.*" > /dev/null; then return 1; fi
}
it 'failed llama helper writes preserve both installed helpers and propagate installation failure' _llama_generation_failure_keeps_helpers

_wallpaper_generation_failure_keeps_files() {
    _feature_sandbox
    mkdir -p "${_WALLSYNC_DESKTOP%/*}"
    printf 'previous wallpaper helper\n' > "$_WALLSYNC_SCRIPT"
    printf 'previous desktop entry\n' > "$_WALLSYNC_DESKTOP"
    local fail_at
    for fail_at in 1 2; do
        if (
            writes=0
            cat() {
                writes=$((writes + 1))
                if [ "$writes" -eq "$fail_at" ]; then
                    printf 'incomplete file\n'
                    return 1
                fi
                command cat "$@"
            }
            app_install_api_wallpaper
        ); then return 1; fi
        assert_eq 'previous wallpaper helper' "$(cat "$_WALLSYNC_SCRIPT")"
        assert_eq 'previous desktop entry' "$(cat "$_WALLSYNC_DESKTOP")"
    done
    if compgen -G "$_WALLSYNC_SCRIPT.tmp.*" > /dev/null; then return 1; fi
    if compgen -G "$_WALLSYNC_DESKTOP.tmp.*" > /dev/null; then return 1; fi
}
it 'failed wallpaper script or desktop writes preserve both installed files and return failure' _wallpaper_generation_failure_keeps_files

print_results
