#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Crush — Termux native (tur-repo)
# 터미널 AI 코딩 에이전트 (Charm). API 키는 사용자가 별도 설정.
# CLI 전용이라 .desktop 런처는 생성하지 않는다.

app_install_crush() {
    termux_pkg_enable_repo tur-repo || return 1
    termux_pkg_install crush || return 1
    echo "[Crush] 'crush' 실행 전 모델 제공자 API 키를 설정하세요."
}

app_remove_crush() {
    termux_pkg_remove crush
}

app_is_installed_crush() {
    termux_pkg_is_installed crush
}
