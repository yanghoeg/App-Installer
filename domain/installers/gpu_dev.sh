#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: GPU 개발 도구 — Termux native (clvk, clinfo 등)

_PKGS_GPU_DEV=(
    clvk
    clinfo
    gtkmm4
    libsigc++-3.0
    libcairomm-1.16
    libglibmm-2.68
    libpangomm-2.48
    swig
    libpeas
)

app_install_gpu_dev() {
    local total=${#_PKGS_GPU_DEV[@]} i=0
    for p in "${_PKGS_GPU_DEV[@]}"; do
        ((++i))
        if termux_pkg_is_installed "$p"; then
            echo "  (${i}/${total}) ${p} — 이미 설치됨"
        else
            echo "  (${i}/${total}) ${p} 설치 중..."
            termux_pkg_install "$p"
        fi
    done
}

app_remove_gpu_dev() {
    for p in "${_PKGS_GPU_DEV[@]}"; do
        termux_pkg_is_installed "$p" && termux_pkg_remove "$p"
    done
}

app_is_installed_gpu_dev() {
    termux_pkg_is_installed clvk
}
