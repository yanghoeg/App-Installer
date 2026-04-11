#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER: pkg_proot_base.sh — proot 실행 공통 구현 (Ubuntu/Arch 공유)
# =============================================================================
# pkg_ubuntu.sh / pkg_arch.sh 가 각각 source 하여 사용.
# 직접 source 하지 말 것 — DI 컨테이너(install.sh)는 distro 어댑터만 로드.

proot_exec() {
    proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" \
        --shared-tmp -- env DISPLAY=:1.0 "$@"
}

proot_exec_wine() {
    proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" \
        --shared-tmp -- env \
            DISPLAY=:1.0 \
            MESA_LOADER_DRIVER_OVERRIDE=zink \
            TU_DEBUG=noconform \
            ZINK_DESCRIPTORS=lazy \
            MESA_NO_ERROR=1 \
        "$@"
}
