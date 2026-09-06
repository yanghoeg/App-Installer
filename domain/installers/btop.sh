#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: btop — Termux native (termux-root)
# 시각적 리소스 모니터 (htop 후속). root-repo 패키지. CLI 전용이라 .desktop 미등록.

app_install_btop() {
    termux_pkg_enable_repo root-repo || return 1
    termux_pkg_install btop || return 1
}

app_remove_btop() {
    termux_pkg_remove btop
}

app_is_installed_btop() {
    termux_pkg_is_installed btop
}
