#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: GPU 가속 (proot) — KGSL mesa + Vulkan WSI Layer (Snapdragon 전용)
# 스켈레톤: 실기기 테스트 후 구현 예정

app_install_gpu_proot() {
    if ! has_proot_distro; then
        echo "[ERROR] proot-distro가 설치되어 있지 않습니다." >&2
        echo "먼저 install.sh로 proot 환경을 구성하세요." >&2
        return 1
    fi

    # KGSL 감지
    if [ ! -f /sys/class/kgsl/kgsl-3d0/gpu_model ]; then
        echo "[ERROR] KGSL GPU가 감지되지 않습니다 (Snapdragon/Adreno 전용)." >&2
        return 1
    fi

    local gpu_model
    gpu_model=$(cat /sys/class/kgsl/kgsl-3d0/gpu_model 2>/dev/null)
    echo "감지된 GPU: ${gpu_model}"

    # TODO: 실기기 테스트 후 구현
    # 1. proot 내 빌드 의존성 설치 (meson, libdrm-dev, libexpat-dev 등)
    # 2. mesa KGSL 패치 빌드 (freedreno_kgsl backend)
    # 3. Vulkan WSI Layer (xMeM) 빌드/설치
    # 4. proot 환경변수 설정 (MESA_LOADER_DRIVER_OVERRIDE, VK_ADD_LAYER_PATH 등)
    echo "[TODO] KGSL mesa + Vulkan WSI Layer 빌드는 아직 구현되지 않았습니다."
    echo "실기기 테스트 후 업데이트 예정입니다."
    return 1
}

app_remove_gpu_proot() {
    # TODO: 빌드 산출물 제거
    echo "[TODO] GPU proot 제거는 아직 구현되지 않았습니다."
    return 1
}

app_is_installed_gpu_proot() {
    # TODO: KGSL-patched mesa 존재 여부
    return 1
}
