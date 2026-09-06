#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: just — Termux native (termux-main)
# make 대체 커맨드 러너. CLI 전용이라 .desktop 미등록.

app_install_just() {
    termux_pkg_install just
}

app_remove_just() {
    termux_pkg_remove just
}

app_is_installed_just() {
    termux_pkg_is_installed just
}
