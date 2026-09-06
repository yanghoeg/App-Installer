#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: AI 업스케일 (ncnn/Vulkan) — Termux native (tur-repo)
# Real-ESRGAN 이미지 확대 + RIFE 프레임 보간. Adreno Vulkan을 직접 쓴다.
# CLI 전용이라 .desktop 런처는 생성하지 않는다.

_PKGS_NCNN_UPSCALE=(realesrgan-ncnn-vulkan rife-ncnn-vulkan)

app_install_ncnn_upscale() {
    termux_pkg_enable_repo tur-repo || return 1
    echo "[ncnn] Real-ESRGAN 모델 포함 약 53MB를 내려받습니다."
    termux_pkg_install "${_PKGS_NCNN_UPSCALE[@]}" || return 1

    if ! app_is_installed_gpu_native 2>/dev/null; then
        echo "[ncnn] 힌트: Vulkan 가속을 쓰려면 '시스템 → GPU 가속'을 먼저 설치하세요."
    fi
    echo "[ncnn] realesrgan-ncnn-vulkan -i in.png -o out.png"
}

app_remove_ncnn_upscale() {
    termux_pkg_remove "${_PKGS_NCNN_UPSCALE[@]}"
}

app_is_installed_ncnn_upscale() {
    termux_pkg_is_installed realesrgan-ncnn-vulkan
}
