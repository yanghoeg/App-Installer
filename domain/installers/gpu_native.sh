#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: GPU 가속 — Termux native (Adreno Vulkan + Zink OpenGL)

_PKGS_GPU_NATIVE=(
    mesa
    mesa-dev
    mesa-demos
    mesa-vulkan-icd-freedreno
    vulkan-loader-generic
    mesa-vulkan-icd-swrast
)

app_install_gpu_native() {
    local total=${#_PKGS_GPU_NATIVE[@]} i=0
    for p in "${_PKGS_GPU_NATIVE[@]}"; do
        ((++i))
        if termux_pkg_is_installed "$p"; then
            echo "  (${i}/${total}) ${p} — 이미 설치됨"
        else
            echo "  (${i}/${total}) ${p} 설치 중..."
            termux_pkg_install "$p"
        fi
    done

    # GPU 감지 로그
    local gpu_model
    gpu_model=$(cat /sys/class/kgsl/kgsl-3d0/gpu_model 2>/dev/null || echo "")
    if [ -n "$gpu_model" ]; then
        echo "감지된 GPU: ${gpu_model}"
        [ -r /dev/dri/renderD128 ] && echo "DRI3 활성" || echo "DRI3 비활성 — Termux:X11 nightly APK 업데이트 권장"
    else
        echo "KGSL GPU 미감지 — llvmpipe 소프트웨어 렌더링으로 실행됩니다."
    fi
}

app_remove_gpu_native() {
    # mesa 자체는 XFCE 의존성이라 유지, GPU 전용 패키지만 제거
    for p in mesa-vulkan-icd-freedreno vulkan-loader-generic mesa-vulkan-icd-swrast mesa-dev mesa-demos; do
        termux_pkg_is_installed "$p" && termux_pkg_remove "$p"
    done
}

app_is_installed_gpu_native() {
    termux_pkg_is_installed mesa-vulkan-icd-freedreno
}
