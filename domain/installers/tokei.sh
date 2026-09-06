#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: tokei — Termux native (termux-main)
# 언어별 코드 라인 수 집계. CLI 전용이라 .desktop 미등록.

app_install_tokei() {
    termux_pkg_install tokei
}

app_remove_tokei() {
    termux_pkg_remove tokei
}

app_is_installed_tokei() {
    termux_pkg_is_installed tokei
}
