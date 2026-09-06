#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: superfile — Termux native (tur-repo)
# 현대적 TUI 파일 매니저. CLI 전용이라 .desktop 런처는 생성하지 않는다.

app_install_superfile() {
    termux_pkg_enable_repo tur-repo || return 1
    termux_pkg_install superfile || return 1
    echo "[superfile] 'spf' 명령으로 실행합니다."
}

app_remove_superfile() {
    termux_pkg_remove superfile
}

app_is_installed_superfile() {
    termux_pkg_is_installed superfile
}
