#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Helix — Termux native (termux-main)
# LSP·tree-sitter 내장 모달 에디터(무설정). 터미널에서 `hx`로 실행하므로 .desktop 미등록.

app_install_helix() {
    termux_pkg_install helix
}

app_remove_helix() {
    termux_pkg_remove helix
}

app_is_installed_helix() {
    termux_pkg_is_installed helix
}
