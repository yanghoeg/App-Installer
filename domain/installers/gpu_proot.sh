#!/data/data/com.termux/files/usr/bin/bash
# Optional container GPU setup. Its glibc Vulkan loader needs a container driver,
# not the host's Bionic library. Activate Zink only after Turnip passes a probe.

_gpu_proot_profile_path() {
    printf '%s/etc/profile.d/gpu-accel.sh\n' "$(_proot_rootfs)"
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
    local rootfs icd='' file probe profile
    rootfs="$(_proot_rootfs)"
    for file in "$rootfs"/usr/share/vulkan/icd.d/freedreno_icd*.json; do
        [ -f "$file" ] || continue
        icd="${file#"$rootfs"}"
        break
    done
    if [ -z "$icd" ]; then
        echo '[ERROR] 컨테이너용 Turnip ICD가 없습니다. 배포판에 맞는 glibc/KGSL Mesa가 필요합니다.' >&2
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
    rm -f "$(_gpu_proot_profile_path)" || return 1
    _gpu_proot_clean_base_profile || return 1
    echo '[OK] GPU proot 설정 제거 완료. 실행 중인 proot 앱은 다시 시작하세요.'
}

app_is_installed_gpu_proot() {
    has_proot_distro || return 1
    [ -f "$(_gpu_proot_profile_path)" ]
}
