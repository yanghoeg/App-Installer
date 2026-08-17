#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: uutils-coreutils — Termux native (tur-repo)
# GNU coreutils의 Rust 재구현. 기본 coreutils를 대체하지 않고 나란히 설치되며,
# 각 명령은 'coreutils <cmd>' 또는 uu- 접두 바이너리로 호출한다.
# CLI 전용이라 .desktop 런처는 생성하지 않는다.

app_install_uutils() {
    termux_pkg_enable_repo tur-repo || return 1
    termux_pkg_install uutils-coreutils || return 1
}

app_remove_uutils() {
    termux_pkg_remove uutils-coreutils
}

app_is_installed_uutils() {
    termux_pkg_is_installed uutils-coreutils
}
