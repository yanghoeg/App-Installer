#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: GPU 가속 (proot) — Termux Turnip Vulkan + Zink OpenGL 공유
# Termux native mesa/vulkan 드라이버를 proot에서 재사용 (Snapdragon/Adreno 전용)

_GPU_PROOT_PROFILE="gpu-accel.sh"
_GPU_PROOT_ICD="${PREFIX}/share/vulkan/icd.d/freedreno_icd.aarch64.json"

_gpu_proot_profile_path() {
    echo "${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/etc/profile.d/${_GPU_PROOT_PROFILE}"
}

app_install_gpu_proot() {
    if ! has_proot_distro; then
        echo "[ERROR] proot-distro가 설치되어 있지 않습니다." >&2
        return 1
    fi

    if [ ! -f /sys/class/kgsl/kgsl-3d0/gpu_model ]; then
        echo "[ERROR] KGSL GPU가 감지되지 않습니다 (Snapdragon/Adreno 전용)." >&2
        return 1
    fi

    local gpu_model
    gpu_model=$(cat /sys/class/kgsl/kgsl-3d0/gpu_model 2>/dev/null)
    echo "감지된 GPU: ${gpu_model}"

    # 1) Termux native GPU 드라이버 확인
    if ! app_is_installed_gpu_native 2>/dev/null; then
        echo "  Termux native GPU 드라이버 설치 중..."
        app_install_gpu_native
    fi

    # 2) proot 검증 도구 설치
    echo "  proot 검증 도구 설치 중..."
    proot_dep mesa_vulkan 2>/dev/null || true
    proot_exec sudo bash -c 'command -v vulkaninfo >/dev/null 2>&1 || {
        if command -v pacman >/dev/null 2>&1; then
            pacman -S --noconfirm --needed vulkan-tools mesa-utils 2>/dev/null || true
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get install -y vulkan-tools mesa-utils 2>/dev/null || true
        fi
    }' 2>/dev/null || true

    # 3) 환경변수 프로파일 생성
    echo "  GPU 환경변수 프로파일 설정 중..."
    local profile_path
    profile_path="$(_gpu_proot_profile_path)"
    mkdir -p "$(dirname "$profile_path")"
    cat > "$profile_path" << 'PROFILE'
# GPU 가속: Termux Turnip Vulkan + Zink OpenGL
export VK_ICD_FILENAMES="/data/data/com.termux/files/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json"
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
export ZINK_DESCRIPTORS=lazy
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE=4.6COMPAT
export MESA_GLSL_VERSION_OVERRIDE=460
export MESA_GLES_VERSION_OVERRIDE=3.2
PROFILE
    chmod 644 "$profile_path"

    # 4) 검증
    echo "  GPU 가속 검증..."
    local vk_test
    vk_test=$(proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" --shared-tmp -- \
        env VK_ICD_FILENAMES="${_GPU_PROOT_ICD}" vulkaninfo --summary 2>/dev/null \
        | grep -E "GPU|driverName|apiVersion" | head -3) || true
    if [ -n "$vk_test" ]; then
        echo "  Vulkan: ${vk_test}"
    else
        echo "  [WARN] Vulkan 검증 실패 — Termux:X11 실행 상태에서 재확인하세요."
    fi
}

app_remove_gpu_proot() {
    local profile_path
    profile_path="$(_gpu_proot_profile_path)"
    rm -f "$profile_path"
    echo "[OK] GPU proot 프로파일 제거 완료."
}

app_is_installed_gpu_proot() {
    [ -f "$(_gpu_proot_profile_path)" ]
}
