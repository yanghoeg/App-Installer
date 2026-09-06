#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: mise — Termux native (termux-main)
# 다국어 버전 매니저(nvm/pyenv 대체). 바이너리만 설치 — 실제 동작하려면
# 사용자가 셸 rc에 `eval "$(mise activate zsh)"`를 직접 추가해야 함. .desktop 미등록.

app_install_mise() {
    termux_pkg_install mise
}

app_remove_mise() {
    termux_pkg_remove mise
}

app_is_installed_mise() {
    termux_pkg_is_installed mise
}
