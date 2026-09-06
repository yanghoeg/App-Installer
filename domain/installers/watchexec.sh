#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: watchexec — Termux native (termux-main)
# 파일 변경 감지 시 명령 재실행. CLI 전용이라 .desktop 미등록.

app_install_watchexec() {
    termux_pkg_install watchexec
}

app_remove_watchexec() {
    termux_pkg_remove watchexec
}

app_is_installed_watchexec() {
    termux_pkg_is_installed watchexec
}
