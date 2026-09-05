#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Miniforge3 — proot 내부 Python 환경
# python/pip 패키지명 차이는 adapter가 흡수

# 버전 핀 + sha256 (releases/latest 대신 고정 태그) — 업스트림 .sha256 에셋과 대조해 갱신할 것.
_MINIFORGE_VER="26.5.3-0"
_MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/download/${_MINIFORGE_VER}/Miniforge3-${_MINIFORGE_VER}-Linux-aarch64.sh"
_MINIFORGE_SHA256="0391e42075a7632e9665d6e728387ee6b905f6c3e704d3513e1c1133d0d69b89"

app_install_miniforge() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    proot_pkg_update || return 1
    proot_pkg_install wget || return 1
    proot_pkg_install_python_pip || return 1

    proot_exec bash -c "$(fetch_verified_src)"$'\n''
        set -e
        fetch_verified "$1" /tmp/miniforge.sh "$2"
        chmod +x /tmp/miniforge.sh
        bash /tmp/miniforge.sh -b
        rm -f /tmp/miniforge.sh
        test -x "$HOME/miniforge3/bin/conda"
    ' _ "$_MINIFORGE_URL" "$_MINIFORGE_SHA256" || { echo "[ERROR] Miniforge 다운로드/설치 실패" >&2; return 1; }
}

app_remove_miniforge() {
    rm -rf "$(_proot_rootfs)/home/${PROOT_USER}/miniforge3"
}

app_is_installed_miniforge() {
    local miniforge_dir
    miniforge_dir="$(_proot_rootfs)/home/${PROOT_USER}/miniforge3"
    [ -d "$miniforge_dir" ]
}
