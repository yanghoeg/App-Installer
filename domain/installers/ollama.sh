#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Ollama — Termux native (termux-main)
# 로컬 LLM 실행기. CLI 전용이라 .desktop 런처는 생성하지 않음.
# 모델은 사용자가 `ollama pull <model>`로 별도 다운로드 (멀티-GB이므로 자동 설치 안 함).

app_install_ollama() {
    termux_pkg_install ollama
}

app_remove_ollama() {
    termux_pkg_remove ollama
}

app_is_installed_ollama() {
    termux_pkg_is_installed ollama
}
