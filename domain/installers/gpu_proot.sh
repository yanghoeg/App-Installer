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

# OpenGL: Ubuntu는 lfdevs/mesa-for-android-container의 Freedreno KGSL(Gallium)을 쓴다 — Zink보다
# 화면 출력이 6~8배 빠르다(SM-F956N glmark2 858 대 108~138). 묶음이 배포판 LLVM에 링크돼 있어
# Ubuntu 버전별 빌드를 고정하고, 배포판 Mesa 파일을 덮지 않도록 별도 경로에 둔다.
# 같은 묶음의 패치 Turnip은 Termux:X11에서 스왑체인 생성이 실패해 Vulkan은 위 드라이버를 유지한다.
GPU_PROOT_MESA_VERSION='26.3.0-devel-20260824'
GPU_PROOT_MESA_DIR='/opt/termux-xfce-mesa'

_gpu_proot_mesa_sha256() {
    case "$1" in
        noble)    echo '06c31d6dd9a404d5f650cfe506521c3c64dc2022a82f12545d0acbcb4544e137' ;;
        questing) echo '66fe0b4e48dbd069689be53f70962ef662bcdb0a383d37e71a70647e08700b5c' ;;
        resolute) echo 'ee762f0855c47f9a245df3ce53a46d40b2240ede9b5c9ddf7606e724362fec77' ;;
        *) return 1 ;;
    esac
}

_gpu_proot_mesa_url() {
    printf 'https://github.com/lfdevs/mesa-for-android-container/releases/download/mesa-%s/mesa-for-android-container_%s_ubuntu_%s_arm64.tar.gz\n' \
        "$GPU_PROOT_MESA_VERSION" "$GPU_PROOT_MESA_VERSION" "$1"
}

_gpu_proot_profile_path() {
    printf '%s/etc/profile.d/gpu-accel.sh\n' "$(_proot_rootfs)"
}

# rootfs가 Ubuntu면 VERSION_CODENAME을 출력한다
_gpu_proot_ubuntu_codename() {
    local release="$(_proot_rootfs)/etc/os-release" codename
    [ -r "$release" ] && grep -qx 'ID=ubuntu' "$release" || return 1
    codename=$(sed -n 's/^VERSION_CODENAME=//p' "$release")
    [ -n "$codename" ] && printf '%s\n' "$codename"
}

# 고정 버전 묶음을 받아 GPU_PROOT_MESA_DIR에 통째로 푼다
_gpu_proot_install_mesa() {
    local codename="$1" sha rootfs tmp
    sha=$(_gpu_proot_mesa_sha256 "$codename") || return 1
    rootfs="$(_proot_rootfs)"
    tmp=$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/mesa.XXXXXX") || return 1
    if ! fetch_verified "$(_gpu_proot_mesa_url "$codename")" "$tmp/mesa.tar.gz" "$sha" ||
        ! mkdir -p "$tmp/x" || ! tar -xzf "$tmp/mesa.tar.gz" -C "$tmp/x" ||
        ! rm -rf "$rootfs$GPU_PROOT_MESA_DIR" || ! mkdir -p "$rootfs${GPU_PROOT_MESA_DIR%/*}" ||
        ! mv "$tmp/x" "$rootfs$GPU_PROOT_MESA_DIR"; then
        rm -rf "$tmp"
        return 1
    fi
    rm -rf "$tmp"
}

# 묶음을 앞세우는 환경 — 검증과 profile이 같은 값을 쓴다
_gpu_proot_mesa_env() {
    local lib="$GPU_PROOT_MESA_DIR/usr/lib/aarch64-linux-gnu"
    printf '%s\n' "LIBGL_DRIVERS_PATH=$lib/dri" "GBM_BACKENDS_PATH=$lib/gbm" \
        "__EGL_VENDOR_LIBRARY_FILENAMES=$GPU_PROOT_MESA_DIR/usr/share/glvnd/egl_vendor.d/50_mesa.json" \
        "MESA_LOADER_DRIVER_OVERRIDE=kgsl"
}

# 화면 없이(surfaceless EGL) Freedreno 렌더러가 잡히는지 본다 — 배포판 LLVM이 맞지 않으면 여기서 걸러진다
_gpu_proot_probe_mesa() {
    local probe lib="$GPU_PROOT_MESA_DIR/usr/lib/aarch64-linux-gnu" env_args
    mapfile -t env_args < <(_gpu_proot_mesa_env)
    probe=$(proot_exec env -u DISPLAY LD_LIBRARY_PATH="$lib" "${env_args[@]}" TURNIP_KMD=kgsl \
        eglinfo -B -p surfaceless 2>&1) && [[ "$probe" =~ renderer:\ FD[0-9] ]]
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

    # 고정 묶음이 있는 Ubuntu만 OpenGL을 Freedreno KGSL로 바꾼다. 안 되면 Zink로 남는다
    local gl=zink codename
    if codename=$(_gpu_proot_ubuntu_codename) && _gpu_proot_mesa_sha256 "$codename" > /dev/null; then
        if _gpu_proot_install_mesa "$codename" && _gpu_proot_probe_mesa; then
            gl=kgsl
        else
            rm -rf "$(_proot_rootfs)$GPU_PROOT_MESA_DIR"
            echo '[WARN] Freedreno KGSL OpenGL 검증 실패 — OpenGL은 Zink로 설정합니다.' >&2
        fi
    fi

    profile="$(_gpu_proot_profile_path)"
    mkdir -p "${profile%/*}" || return 1
    if [ "$gl" = kgsl ]; then
        {
            printf '%s\n' '# Optional GPU configuration managed by App Installer.' \
                "export VK_DRIVER_FILES=\"$icd\"" 'export TURNIP_KMD=kgsl' 'export TU_DEBUG=noconform' \
                '# OpenGL은 Freedreno KGSL(lfdevs Mesa) — 배포판 Mesa 파일은 그대로 두고 경로로 앞세운다' \
                "export LD_LIBRARY_PATH=\"$GPU_PROOT_MESA_DIR/usr/lib/aarch64-linux-gnu\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}\""
            _gpu_proot_mesa_env | sed 's/^/export /'
        } > "$profile" || return 1
    else
        cat > "$profile" <<PROFILE || return 1
# Optional GPU configuration managed by App Installer.
export VK_DRIVER_FILES="$icd"
export TURNIP_KMD=kgsl
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
export ZINK_DESCRIPTORS=lazy
PROFILE
    fi
    chmod 644 "$profile" || return 1
    _gpu_proot_clean_base_profile || return 1
    if [ "$gl" = kgsl ]; then
        echo '[OK] 컨테이너 Turnip + Freedreno KGSL OpenGL 설정 완료. proot 앱을 다시 시작하세요.'
    else
        echo '[OK] 컨테이너 Turnip + Zink 설정 완료. proot 앱을 다시 시작하세요.'
    fi
}

app_remove_gpu_proot() {
    has_proot_distro || { echo '[ERROR] proot 환경이 필요합니다.' >&2; return 1; }
    local rootfs; rootfs="$(_proot_rootfs)"
    rm -f "$(_gpu_proot_profile_path)" "$rootfs$GPU_PROOT_TURNIP_ICD" "$rootfs$GPU_PROOT_TURNIP_LIB" || return 1
    rm -rf "$rootfs$GPU_PROOT_MESA_DIR" || return 1
    _gpu_proot_clean_base_profile || return 1
    echo '[OK] GPU proot 설정 제거 완료. 실행 중인 proot 앱은 다시 시작하세요.'
}

app_is_installed_gpu_proot() {
    has_proot_distro || return 1
    [ -f "$(_gpu_proot_profile_path)" ]
}
