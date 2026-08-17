#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Codex CLI — Termux native (tur-repo)
# OpenAI 코딩 에이전트 CLI. API 키는 사용자가 별도 설정.
# CLI 전용이라 .desktop 런처는 생성하지 않는다.

app_install_codex() {
    termux_pkg_enable_repo tur-repo || return 1
    termux_pkg_install codex || return 1
    echo "[Codex] 'codex' 실행 전 OPENAI_API_KEY를 설정하세요."
}

app_remove_codex() {
    termux_pkg_remove codex
}

app_is_installed_codex() {
    termux_pkg_is_installed codex
}
