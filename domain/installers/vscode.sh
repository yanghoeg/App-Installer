#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Visual Studio Code — proot 내부 설치, prun으로 실행
# Arch: AUR visual-studio-code-bin (yay 사용)
# Ubuntu: Microsoft 공식 arm64 repo 추가 후 설치

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
    # proot 안에 실제 binary가 있는지 확인 (desktop 파일만으론 부족)
    proot_exec bash -c "command -v code" &>/dev/null
}
