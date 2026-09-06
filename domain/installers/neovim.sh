#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Neovim — Termux native (termux-main)
# 터미널 모달 에디터. 터미널에서 `nvim`으로 실행하므로 .desktop 런처는 생성하지 않음.

app_install_neovim() {
    termux_pkg_install neovim
}

app_remove_neovim() {
    termux_pkg_remove neovim
}

app_is_installed_neovim() {
    termux_pkg_is_installed neovim
}
