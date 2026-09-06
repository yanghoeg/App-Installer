#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: LibreOffice — proot 내부 설치
# 패키지명 차이(libreoffice vs libreoffice-fresh)는 adapter가 흡수

app_install_libreoffice() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    proot_pkg_update || return 1
    proot_pkg_install_libreoffice || return 1
    proot_setup_bwrap || return 1
    desktop_copy_from_proot "libreoffice"
}

app_remove_libreoffice() {
    proot_pkg_remove_libreoffice 2>/dev/null || true
    proot_pkg_autoremove
    desktop_remove_prefix "libreoffice"
}

app_is_installed_libreoffice() {
    desktop_is_registered "libreoffice-base"
}
