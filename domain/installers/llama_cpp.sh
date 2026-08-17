#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: llama.cpp — Termux native (termux-main)
# GGUF 모델 직접 추론. CLI 전용이라 .desktop 런처는 생성하지 않는다.
# Vulkan(Adreno) / OpenCL 백엔드를 함께 설치하며, 초기화 실패 시 CPU로 폴백한다.
# 모델(GGUF)은 사용자가 별도로 받아야 한다 — 멀티-GB이므로 자동 다운로드 안 함.

_PKGS_LLAMA_CPP=(llama-cpp llama-cpp-backend-vulkan llama-cpp-backend-opencl)

app_install_llama_cpp() {
    termux_pkg_install "${_PKGS_LLAMA_CPP[@]}" || return 1

    if ! app_is_installed_gpu_native 2>/dev/null; then
        echo "[llama.cpp] 힌트: GPU 추론을 쓰려면 '시스템 → GPU 가속'을 먼저 설치하세요."
    fi
    echo "[llama.cpp] llama-cli / llama-server 사용 가능. GGUF 모델은 직접 받아야 합니다."
}

app_remove_llama_cpp() {
    # 백엔드 패키지는 llama-cpp 에 의존하므로 함께 제거된다
    termux_pkg_remove llama-cpp
}

app_is_installed_llama_cpp() {
    termux_pkg_is_installed llama-cpp
}
