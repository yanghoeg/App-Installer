#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Visual Studio Code — Termux native (code-oss)
# MS 공식 VSCode의 오픈소스 빌드. Marketplace 대신 Open VSX 사용.
# proot x86_64 tarball/AUR 우회 없이 arm64 네이티브로 바로 실행.

app_install_vscode() {
    termux_pkg_install code-oss
    desktop_register "code-oss" "Visual Studio Code - OSS" \
        "code-oss --no-sandbox --disable-gpu %F" "code-oss" \
        "Development;IDE;" \
        "MimeType=text/plain;inode/directory;"
}

app_remove_vscode() {
    termux_pkg_remove code-oss
    desktop_remove "code-oss"
}

app_is_installed_vscode() {
    termux_pkg_is_installed code-oss && desktop_is_registered "code-oss"
}
