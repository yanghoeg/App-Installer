#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Visual Studio Code — proot 내부 설치
# Ubuntu: Microsoft 공식 arm64 repo 추가 후 설치
# Arch: extra/code (repo 불필요, adapter가 add_external_repo를 no-op 처리)

app_install_vscode() {
    proot_pkg_update
    proot_pkg_install_vscode
    desktop_register "code" "Visual Studio Code" "prun code --no-sandbox" \
        "visual-studio-code" "Development;"
}

app_remove_vscode() {
    proot_pkg_remove_vscode
    proot_pkg_autoremove
    desktop_remove "code"
}

app_is_installed_vscode() {
    desktop_is_registered "code"
}
