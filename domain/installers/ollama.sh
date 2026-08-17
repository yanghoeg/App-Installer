#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Ollama — Termux native (termux-main)
# 로컬 LLM 실행기. CLI 전용이라 .desktop 런처는 생성하지 않는다.
# 모델은 사용자가 `ollama pull <model>`로 별도 다운로드 (멀티-GB이므로 자동 설치 안 함).
#
# ollama-backend-vulkan: Adreno Vulkan GPU 추론 백엔드. ollama가 런타임에 로드하며
# Vulkan 초기화에 실패하면 CPU로 폴백한다. GPU를 실제로 쓰려면 '시스템 → GPU 가속'
# (gpu_native)으로 mesa-vulkan-icd-freedreno / vulkan-loader-generic 이 먼저 깔려야 한다.

_PKGS_OLLAMA=(ollama ollama-backend-vulkan)

app_install_ollama() {
    termux_pkg_install "${_PKGS_OLLAMA[@]}" || return 1

    if ! app_is_installed_gpu_native 2>/dev/null; then
        echo "[Ollama] 힌트: GPU 추론을 쓰려면 '시스템 → GPU 가속'을 먼저 설치하세요."
    fi
}

app_remove_ollama() {
    # ollama-backend-vulkan 은 ollama 에 의존하므로 함께 제거된다
    termux_pkg_remove ollama
}

app_is_installed_ollama() {
    termux_pkg_is_installed ollama
}
