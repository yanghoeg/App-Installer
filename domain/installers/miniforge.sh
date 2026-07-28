#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Miniforge3 — proot 내부 Python 환경
# python/pip 패키지명 차이는 adapter가 흡수

app_install_miniforge() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    proot_pkg_update || return 1
    proot_pkg_install wget || return 1
    proot_pkg_install_python_pip || return 1

    proot_exec bash -c "
        set -e
        wget -O /tmp/miniforge.sh \
            https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh
        chmod +x /tmp/miniforge.sh
        bash /tmp/miniforge.sh -b
        rm -f /tmp/miniforge.sh
        test -x \"\$HOME/miniforge3/bin/conda\"
    " || { echo "[ERROR] Miniforge 다운로드/설치 실패" >&2; return 1; }
}

app_remove_miniforge() {
    rm -rf "$(_proot_rootfs)/home/${PROOT_USER}/miniforge3"
}

app_is_installed_miniforge() {
    local miniforge_dir
    miniforge_dir="$(_proot_rootfs)/home/${PROOT_USER}/miniforge3"
    [ -d "$miniforge_dir" ]
}
