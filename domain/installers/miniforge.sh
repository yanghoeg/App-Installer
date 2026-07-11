#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Miniforge3 — proot 내부 Python 환경
# python/pip 패키지명 차이는 adapter가 흡수

app_install_miniforge() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    proot_pkg_update
    proot_pkg_install wget
    proot_pkg_install_python_pip

    proot_exec bash -c "
        wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh
        chmod +x Miniforge3-Linux-aarch64.sh
        bash Miniforge3-Linux-aarch64.sh -b
        rm -f Miniforge3-Linux-aarch64.sh
    "
}

app_remove_miniforge() {
    rm -rf "${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/${PROOT_USER}/miniforge3"
}

app_is_installed_miniforge() {
    local miniforge_dir="${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/${PROOT_USER}/miniforge3"
    [ -d "$miniforge_dir" ]
}
