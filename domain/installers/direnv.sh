#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: direnv — Termux native (termux-main)
# 디렉터리별 환경변수 자동 로드. 바이너리만 설치 — 실제 동작하려면
# 사용자가 셸 rc에 `eval "$(direnv hook zsh)"`를 직접 추가해야 함. .desktop 미등록.

app_install_direnv() {
    termux_pkg_install direnv
}

app_remove_direnv() {
    termux_pkg_remove direnv
}

app_is_installed_direnv() {
    termux_pkg_is_installed direnv
}
