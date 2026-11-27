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

_gpu_native_set_state() {
    local state="$1" dir="$HOME/.config/termux-xfce" stage
    mkdir -p "$dir" || return 1
    stage=$(mktemp "$dir/.gpu-native.XXXXXX") || return 1
    if ! printf '%s\n' "$state" > "$stage" || ! mv -fT -- "$stage" "$dir/gpu-native"; then
        rm -f -- "$stage"
        return 1
    fi
}

app_install_gpu_native() {
    termux_pkg_enable_repo x11-repo || return 1
    local total=${#_PKGS_GPU_NATIVE[@]} i=0
    for p in "${_PKGS_GPU_NATIVE[@]}"; do
        ((++i))
        if termux_pkg_is_installed "$p"; then
            echo "  (${i}/${total}) ${p} — 이미 설치됨"
        else
            echo "  (${i}/${total}) ${p} 설치 중..."
            termux_pkg_install "$p" || return 1
        fi
    done

    _gpu_native_set_state enabled || return 1

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
    # These packages are also used by Plasma and standalone Vulkan apps.
    _gpu_native_set_state disabled || return 1
    echo "[OK] X11 데스크톱 GPU 가속을 껐습니다. XFCE 재시작 후 적용됩니다."
}

app_is_installed_gpu_native() {
    local state=''
    if [ -r "$HOME/.config/termux-xfce/gpu-native" ]; then
        IFS= read -r state < "$HOME/.config/termux-xfce/gpu-native" || true
    fi
    [ "$state" != disabled ] || return 1
    termux_pkg_is_installed mesa-vulkan-icd-freedreno
}
