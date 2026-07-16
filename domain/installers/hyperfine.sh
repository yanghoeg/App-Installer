#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: hyperfine — Termux native (termux-main)
# 통계 기반 CLI 벤치마킹 도구. CLI 전용이라 .desktop 미등록.

app_install_hyperfine() {
    termux_pkg_install hyperfine
}

app_remove_hyperfine() {
    termux_pkg_remove hyperfine
}

app_is_installed_hyperfine() {
    termux_pkg_is_installed hyperfine
}
