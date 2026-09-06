#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: aichat — Termux native (termux-main)
# 터미널 AI 어시스턴트 CLI. 로컬(llama.cpp llama-server) 또는 클라우드 API(Claude/GPT 등)와 연동.
# CLI 전용이라 .desktop 런처는 생성하지 않음. 모델/API 키는 사용자가 별도 설정.

app_install_aichat() {
    termux_pkg_install aichat
}

app_remove_aichat() {
    termux_pkg_remove aichat
}

app_is_installed_aichat() {
    termux_pkg_is_installed aichat
}
