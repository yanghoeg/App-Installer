#!/data/data/com.termux/files/usr/bin/bash
# Mock regressions for review findings #7, #8, #9 and #12.
_REVIEW_APP_DIR="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
source "$_REVIEW_APP_DIR/tests/framework.sh"
source "$_REVIEW_APP_DIR/lib/common.sh"
source "$_REVIEW_APP_DIR/lib/input_method.sh"
source "$_REVIEW_APP_DIR/domain/installers/gpu_proot.sh"

_review_sandbox() {
    _REVIEW_SANDBOX=$(make_sandbox)
    trap 'cleanup_sandbox "$_REVIEW_SANDBOX"' EXIT
    export HOME="$_REVIEW_SANDBOX/home" PREFIX="$_REVIEW_SANDBOX/usr"
    export PROOT_ROOTFS_BASE="$_REVIEW_SANDBOX/containers"
    mkdir -p "$HOME/.config/termux-xfce" "$PREFIX/etc" "$PREFIX/bin"
    : > "$PREFIX/etc/bash.bashrc"
    : > "$HOME/.zshrc"
    unset WAYLAND_DISPLAY XDG_SESSION_TYPE PROOT_DISTRO PROOT_USER
    _REVIEW_NIMF_PRESENT=false
    _REVIEW_FCITX_PRESENT=false
    # Binary availability must not depend on packages installed on the test host.
    command() {
        if [ "${1:-}" = -v ]; then
            case "${2:-}" in
                nimf) [ "$_REVIEW_NIMF_PRESENT" = true ]; return $? ;;
                fcitx5) [ "$_REVIEW_FCITX_PRESENT" = true ]; return $? ;;
            esac
        fi
        builtin command "$@"
    }
}

_review_alarm_user() {
    _review_sandbox
    export PROOT_DISTRO=archlinux
    local layout rootfs
    for layout in containers/archlinux/rootfs installed-rootfs/archlinux; do
        rootfs="$PROOT_ROOTFS_BASE/$layout"
        mkdir -p "$rootfs/home/alarm" "$rootfs/home/realuser"
        assert_eq realuser "$(_detect_proot_user)"
        rm -rf "$rootfs"
    done
    mkdir -p "$PROOT_ROOTFS_BASE/containers/archlinux/rootfs/home/alarm"
    assert_eq user "$(_detect_proot_user)"
}
it 'automatic proot user detection excludes alarm in both rootfs layouts' _review_alarm_user

_review_config_override_user() {
    _review_sandbox
    mkdir -p "$PROOT_ROOTFS_BASE/containers/archlinux/rootfs/home/alarm" \
        "$PROOT_ROOTFS_BASE/containers/archlinux/rootfs/home/realuser"
    printf 'PROOT_DISTRO=ubuntu\nPROOT_USER=ubuntuuser\n' > "$HOME/.config/termux-xfce/config"
    export PROOT_DISTRO=archlinux
    _load_app_config
    assert_eq archlinux "$PROOT_DISTRO"
    assert_eq realuser "$PROOT_USER"
    export PROOT_USER=alarm
    _load_app_config
    assert_eq alarm "$PROOT_USER" 'an explicit user remains supported'
}
it 'a distro override detects the real user while preserving explicit user choices' _review_config_override_user

_review_legacy_without_binary() {
    _review_sandbox
    cat > "$PREFIX/etc/bash.bashrc" <<'RC'
# termux-xfce-locale
export LANG=ko_KR.UTF-8
if command -v nimf >/dev/null 2>&1; then
    export GTK_IM_MODULE=nimf
    export QT_IM_MODULE=nimf
    export XMODIFIERS=@im=nimf
fi
export KEEP_USER_SETTING=yes
RC
    mkdir -p "$HOME/.config/autostart"
    printf '[Desktop Entry]\nExec=nimf\nHidden=false\n' > "$HOME/.config/autostart/nimf.desktop"
    input_method_setup
    assert_eq none "$(input_method_current)"
    source "$PREFIX/etc/profile.d/termux-xfce-input.sh"
    assert_eq unset "${GTK_IM_MODULE-unset}"
    assert_eq unset "${QT_IM_MODULE-unset}"
    assert_eq unset "${XMODIFIERS-unset}"
    assert_file_contains "$HOME/.config/autostart/nimf.desktop" '^Hidden=true$'
    assert_file_contains "$PREFIX/etc/bash.bashrc" '^export KEEP_USER_SETTING=yes$'
}
it 'legacy guarded Nimf settings and autostart do not select an absent binary' _review_legacy_without_binary

_review_legacy_available_binary() {
    _review_sandbox
    _REVIEW_NIMF_PRESENT=true
    printf 'export GTK_IM_MODULE=nimf\n' >> "$PREFIX/etc/bash.bashrc"
    printf 'export GTK_IM_MODULE=fcitx5\n' >> "$HOME/.zshrc"
    input_method_setup
    assert_eq nimf "$(input_method_current)" 'an absent Fcitx does not override installed Nimf'
    rm -f "$HOME/.config/termux-xfce/input-method"
    _REVIEW_FCITX_PRESENT=true
    input_method_setup
    assert_eq fcitx5 "$(input_method_current)" 'installed Fcitx has migration precedence'
}
it 'legacy migration imports available binaries and preserves Fcitx precedence' _review_legacy_available_binary

_review_hidden_preserved() {
    _review_sandbox
    local selected id
    for selected in nimf fcitx5; do
        id=nimf
        [ "$selected" = nimf ] || id=org.fcitx.Fcitx5
        input_method_select "$selected"
        sed -i 's/^Hidden=false$/Hidden=true/' "$HOME/.config/autostart/$id.desktop"
        input_method_setup
        input_method_setup
        assert_file_contains "$HOME/.config/autostart/$id.desktop" '^Hidden=true$'
        input_method_select "$selected"
        assert_file_contains "$HOME/.config/autostart/$id.desktop" '^Hidden=false$'
    done
    assert_file_contains "$HOME/.config/autostart/nimf.desktop" '^Hidden=true$'
}
it 'setup preserves disabled autostart and explicit selection enables the chosen method' _review_hidden_preserved

_review_legacy_hidden_selection() {
    _review_sandbox
    _REVIEW_NIMF_PRESENT=true
    _REVIEW_FCITX_PRESENT=true
    printf 'export GTK_IM_MODULE=fcitx5\n' >> "$HOME/.zshrc"
    # Written by a Nimf-era installer, before the selection key existed.
    mkdir -p "$HOME/.config/autostart"
    printf '[Desktop Entry]\nExec=fcitx5 -d\nHidden=true\n' > "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop"
    printf '[Desktop Entry]\nExec=nimf\nHidden=false\n' > "$HOME/.config/autostart/nimf.desktop"
    input_method_setup
    assert_eq fcitx5 "$(input_method_current)"
    assert_file_contains "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop" '^Hidden=false$'
    assert_file_contains "$HOME/.config/autostart/nimf.desktop" '^Hidden=true$'
}
it 'a legacy entry hidden by an older installer starts once its method is imported as selected' _review_legacy_hidden_selection

_review_config_change_follows_selection() {
    _review_sandbox
    input_method_select nimf
    printf 'fcitx5\n' > "$HOME/.config/termux-xfce/input-method"
    input_method_setup
    assert_file_contains "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop" '^Hidden=false$'
    assert_file_contains "$HOME/.config/autostart/nimf.desktop" '^Hidden=true$'
    # A later user choice to disable the newly selected method still survives setup.
    sed -i 's/^Hidden=false$/Hidden=true/' "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop"
    input_method_setup
    assert_file_contains "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop" '^Hidden=true$'
}
it 'a selection changed in the config file enables its autostart on the next setup' _review_config_change_follows_selection

_review_nimf_guard() {
    _review_sandbox
    input_method_select nimf
    export PATH="$PREFIX/bin:$PATH" REVIEW_NIMF_LOG="$_REVIEW_SANDBOX/nimf.log"
    cat > "$PREFIX/bin/pgrep" <<'STUB'
#!/data/data/com.termux/files/usr/bin/bash
[ "$*" = '-x nimf' ] || exit 2
[ "$REVIEW_NIMF_RUNNING" = true ]
STUB
    cat > "$PREFIX/bin/nimf" <<'STUB'
#!/data/data/com.termux/files/usr/bin/bash
printf 'started\n' >> "$REVIEW_NIMF_LOG"
STUB
    chmod +x "$PREFIX/bin/pgrep" "$PREFIX/bin/nimf"
    local desktop_exec
    desktop_exec=$(sed -n 's/^Exec=//p' "$HOME/.config/autostart/nimf.desktop")
    export REVIEW_NIMF_RUNNING=true
    bash -c "$desktop_exec"
    [ ! -f "$REVIEW_NIMF_LOG" ]
    export REVIEW_NIMF_RUNNING=false
    bash -c "$desktop_exec"
    assert_eq started "$(cat "$REVIEW_NIMF_LOG")"
}
it 'the generated Nimf autostart starts only when no Nimf process is running' _review_nimf_guard

_review_gpu_legacy_install() {
    _review_sandbox
    export PROOT_DISTRO=archlinux
    local rootfs="$PROOT_ROOTFS_BASE/containers/archlinux/rootfs"
    mkdir -p "$rootfs/etc/profile.d" "$rootfs/usr/share/vulkan/icd.d"
    cat > "$rootfs/etc/profile.d/termux-xfce-env.sh" <<'PROFILE'
export DISPLAY=${DISPLAY:-:0}
export MESA_LOADER_DRIVER_OVERRIDE=zink
export VK_ICD_FILENAMES=/host/freedreno_icd.json
export KEEP_USER_SETTING=yes
PROFILE
    : > "$rootfs/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json"
    has_proot_distro() { [ -n "${PROOT_DISTRO:-}" ]; }
    _gpu_proot_has_kgsl() { return 0; }
    proot_pkg_install_wine_mesa() { return 0; }
    proot_pkg_install_gpu_tools() { return 0; }
    proot_exec() {
        printf '%s\n' "$*" > "$_REVIEW_SANDBOX/probe-args"
        printf 'driverName = turnip\n'
    }
    if app_is_installed_gpu_proot; then
        echo '[ASSERT] legacy host ICD settings must not count as probed GPU setup' >&2
        return 1
    fi
    app_install_gpu_proot > /dev/null
    app_is_installed_gpu_proot
    assert_file_contains "$_REVIEW_SANDBOX/probe-args" 'TURNIP_KMD=kgsl vulkaninfo --summary'
    assert_file_contains "$rootfs/etc/profile.d/gpu-accel.sh" '^export VK_DRIVER_FILES="/usr/share/vulkan/icd.d/'
    if grep -Eq '^export (MESA_|VK_)' "$rootfs/etc/profile.d/termux-xfce-env.sh"; then
        echo '[ASSERT] legacy GPU exports remain after successful migration' >&2
        return 1
    fi
    assert_file_contains "$rootfs/etc/profile.d/termux-xfce-env.sh" '^export KEEP_USER_SETTING=yes$'
    app_remove_gpu_proot > /dev/null
    if app_is_installed_gpu_proot; then return 1; fi
}
it 'legacy GPU exports allow a fresh container Turnip probe and profile migration' _review_gpu_legacy_install

_review_fcitx_keeps_nimf() {
    _review_sandbox
    source "$_REVIEW_APP_DIR/domain/installers/korean_input.sh"
    _REVIEW_NIMF_PRESENT=true
    input_method_select nimf
    local -A packages=([fcitx5]=yes [fcitx5-hangul]=yes [libhangul]=yes [libhangul-static]=yes [nimf]=yes)
    termux_pkg_is_installed() { [ "${packages[$1]:-}" = yes ]; }
    termux_pkg_remove() {
        unset 'packages[$1]'
        # Model apt's real dependency cascade if a shared library is removed.
        if [ "$1" = libhangul ]; then
            unset 'packages[nimf]'
            _REVIEW_NIMF_PRESENT=false
        fi
    }
    app_remove_korean_input
    assert_eq yes "${packages[nimf]:-}"
    assert_eq yes "${packages[libhangul]:-}"
    assert_eq yes "${packages[libhangul-static]:-}"
    assert_eq nimf "$(input_method_current)"
    assert_file_contains "$HOME/.config/autostart/nimf.desktop" '^Hidden=false$'
    [ -z "${packages[fcitx5-hangul]:-}" ]
}
it 'removing native Fcitx preserves shared Hangul libraries and selected Nimf' _review_fcitx_keeps_nimf

_review_arch_fcitx_has_gtk() {
    _review_sandbox
    source "$_REVIEW_APP_DIR/domain/installers/korean_proot.sh"
    export PROOT_DISTRO=archlinux PROOT_USER=desktop
    local -a installed=()
    has_proot_distro() { return 0; }
    _proot_rootfs() { printf '%s\n' "$_REVIEW_SANDBOX/rootfs"; }
    proot_pkg_is_installed() { return 1; }
    proot_pkg_install_aur() { return 1; }
    proot_pkg_install() { installed+=("$@"); }
    proot_exec() { return 0; }
    app_install_korean_proot
    local p found=false
    for p in "${installed[@]}"; do [ "$p" != fcitx5-gtk ] || found=true; done
    assert_eq true "$found"
    assert_file_contains "$_REVIEW_SANDBOX/rootfs/etc/profile.d/termux-xfce-locale.sh" '^export GTK_IM_MODULE=fcitx$'
}
it 'Arch Nimf failure installs the Fcitx GTK frontend before selecting Fcitx' _review_arch_fcitx_has_gtk

_review_arch_gtk_failure_stops_selection() {
    _review_sandbox
    source "$_REVIEW_APP_DIR/domain/installers/korean_proot.sh"
    export PROOT_DISTRO=archlinux PROOT_USER=desktop
    has_proot_distro() { return 0; }
    _proot_rootfs() { printf '%s\n' "$_REVIEW_SANDBOX/rootfs"; }
    proot_pkg_is_installed() { return 1; }
    proot_pkg_install_aur() { return 1; }
    proot_pkg_install() { [ "$1" != fcitx5-gtk ]; }
    proot_exec() { return 0; }
    if app_install_korean_proot; then return 1; fi
    [ ! -e "$_REVIEW_SANDBOX/rootfs/etc/profile.d/termux-xfce-locale.sh" ]
}
it 'a missing Fcitx GTK frontend fails instead of recording a broken input method' _review_arch_gtk_failure_stops_selection

print_results
