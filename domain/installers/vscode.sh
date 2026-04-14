#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Visual Studio Code — proot 내부 설치, prun으로 실행
# Arch: Microsoft 공식 arm64 tar.gz → /opt/visual-studio-code/
# Ubuntu: Microsoft 공식 arm64 apt repo → /usr/share/code/

app_install_vscode() {
    proot_pkg_update
    proot_pkg_install_vscode
    local exec_cmd
    case "${PROOT_DISTRO:-}" in
        archlinux) exec_cmd='bash -c "prun dbus-run-session -- /opt/visual-studio-code/code --no-sandbox --disable-gpu </dev/null >/dev/null 2>&1 &"' ;;
        ubuntu)    exec_cmd='bash -c "prun dbus-run-session -- /usr/share/code/code --no-sandbox --disable-gpu </dev/null >/dev/null 2>&1 &"' ;;
        *)         exec_cmd='bash -c "prun code --no-sandbox </dev/null >/dev/null 2>&1 &"' ;;
    esac
    desktop_register "code" "Visual Studio Code" "$exec_cmd" \
        "visual-studio-code" "Development;"
}

app_remove_vscode() {
    proot_pkg_remove_vscode
    proot_pkg_autoremove
    desktop_remove "code"
}

app_is_installed_vscode() {
    # 실제 binary 경로로 확인 (command -v는 wrapper/잔재 스크립트를 잡을 수 있음)
    case "${PROOT_DISTRO:-}" in
        archlinux) proot_exec bash -c "[ -f /opt/visual-studio-code/code ]" &>/dev/null ;;
        ubuntu)    proot_exec bash -c "[ -f /usr/share/code/code ]" &>/dev/null ;;
        *)         proot_exec bash -c "command -v code" &>/dev/null ;;
    esac
}
