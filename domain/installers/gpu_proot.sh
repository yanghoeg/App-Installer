#!/data/data/com.termux/files/usr/bin/bash
# Optional container GPU setup. Its glibc Vulkan loader needs a container driver,
# not the host's Bionic library. Activate Zink only after Turnip passes a probe.
# 배포판 Turnip은 msm(DRM) 전용이라 Android KGSL에서 GPU를 못 찾는다 → Termux glibc-repo의
# KGSL Turnip 드라이버만 rootfs에 넣는다. RUNPATH가 없어 의존 라이브러리는 배포판 것을 쓴다.

GPU_PROOT_TURNIP_VERSION='24.2.6'
GPU_PROOT_TURNIP_SHA256='f45523463ae7a6b19c5c4e77bf42eff38124dfe13cc97fce34fc2bf820f41c6a'
GPU_PROOT_TURNIP_URL="https://packages-cf.termux.dev/apt/termux-glibc/pool/stable/m/mesa-vulkan-icd-freedreno-glibc/mesa-vulkan-icd-freedreno-glibc_${GPU_PROOT_TURNIP_VERSION}_aarch64.deb"
GPU_PROOT_TURNIP_LIB='/usr/local/lib/termux-turnip/libvulkan_freedreno.so'
GPU_PROOT_TURNIP_ICD='/usr/share/vulkan/icd.d/termux_freedreno_icd.aarch64.json'

_gpu_proot_profile_path() {
    printf '%s/etc/profile.d/gpu-accel.sh\n' "$(_proot_rootfs)"
}

# 고정 버전 .deb에서 드라이버 하나만 꺼내 rootfs에 넣고 게스트 경로 ICD를 쓴다
_gpu_proot_install_termux_turnip() {
    local rootfs tmp
    rootfs="$(_proot_rootfs)"
    tmp=$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/turnip.XXXXXX") || return 1
    if ! fetch_verified "$GPU_PROOT_TURNIP_URL" "$tmp/turnip.deb" "$GPU_PROOT_TURNIP_SHA256" ||
        ! dpkg-deb -x "$tmp/turnip.deb" "$tmp/x" ||
        ! install -D -m 644 "$tmp/x/data/data/com.termux/files/usr/glibc/lib/libvulkan_freedreno.so" \
            "$rootfs$GPU_PROOT_TURNIP_LIB"; then
        rm -rf "$tmp"
        return 1
    fi
    rm -rf "$tmp"
    mkdir -p "$(dirname "$rootfs$GPU_PROOT_TURNIP_ICD")" || return 1
    cat > "$rootfs$GPU_PROOT_TURNIP_ICD" <<ICD
{
    "ICD": {
        "api_version": "1.1.289",
        "library_path": "$GPU_PROOT_TURNIP_LIB"
    },
    "file_format_version": "1.0.0"
}
ICD
}

_gpu_proot_has_kgsl() { [ -r /dev/kgsl-3d0 ]; }

_gpu_proot_clean_base_profile() {
    local profile="$(_proot_rootfs)/etc/profile.d/termux-xfce-env.sh"
    [ -f "$profile" ] || return 0
    sed -i -E '/^export (MESA_[A-Z_]+|TU_DEBUG|ZINK_DESCRIPTORS|vblank_mode|VK_ICD_FILENAMES|VK_DRIVER_FILES)=/d' "$profile"
}

app_install_gpu_proot() {
    has_proot_distro || { echo '[ERROR] proot 환경이 필요합니다.' >&2; return 1; }
    _gpu_proot_has_kgsl || { echo '[ERROR] 읽을 수 있는 Adreno/KGSL 장치가 필요합니다.' >&2; return 1; }

    proot_pkg_install_wine_mesa || return 1
    proot_pkg_install_gpu_tools || return 1
    local icd="$GPU_PROOT_TURNIP_ICD" probe profile
    if ! _gpu_proot_install_termux_turnip; then
        echo '[ERROR] KGSL Turnip 드라이버(Termux glibc-repo)를 받지 못했습니다.' >&2
        return 1
    fi
    if ! probe=$(proot_exec env VK_DRIVER_FILES="$icd" VK_ICD_FILENAMES="$icd" \
        TURNIP_KMD=kgsl vulkaninfo --summary 2>&1) || ! [[ "$probe" =~ [Tt]urnip ]]; then
        echo '[ERROR] 컨테이너 Turnip/KGSL 검증 실패 — GPU 설정을 활성화하지 않았습니다.' >&2
        printf '%s\n' "$probe" >&2
        return 1
    fi

    profile="$(_gpu_proot_profile_path)"
    mkdir -p "${profile%/*}" || return 1
    cat > "$profile" <<PROFILE || return 1
# Optional GPU configuration managed by App Installer.
export VK_DRIVER_FILES="$icd"
export TURNIP_KMD=kgsl
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
export ZINK_DESCRIPTORS=lazy
PROFILE
    chmod 644 "$profile" || return 1
    _gpu_proot_clean_base_profile || return 1
    echo '[OK] 컨테이너 Turnip + Zink 설정 완료. proot 앱을 다시 시작하세요.'
}

app_remove_gpu_proot() {
    has_proot_distro || { echo '[ERROR] proot 환경이 필요합니다.' >&2; return 1; }
    local rootfs; rootfs="$(_proot_rootfs)"
    rm -f "$(_gpu_proot_profile_path)" "$rootfs$GPU_PROOT_TURNIP_ICD" "$rootfs$GPU_PROOT_TURNIP_LIB" || return 1
    _gpu_proot_clean_base_profile || return 1
    echo '[OK] GPU proot 설정 제거 완료. 실행 중인 proot 앱은 다시 시작하세요.'
}

app_is_installed_gpu_proot() {
    has_proot_distro || return 1
    [ -f "$(_gpu_proot_profile_path)" ]
}
