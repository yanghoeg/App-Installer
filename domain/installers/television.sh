#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: television — Termux native (tur-repo)
# 채널 기반 퍼지 파인더 (fzf 대안). CLI 전용이라 .desktop 런처는 생성하지 않는다.

app_install_television() {
    termux_pkg_enable_repo tur-repo || return 1
    termux_pkg_install television || return 1
    echo "[television] 'tv' 명령으로 실행합니다."
}

app_remove_television() {
    termux_pkg_remove television
}

app_is_installed_television() {
    termux_pkg_is_installed television
}
