#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: LibreOffice — proot 내부 설치
# 패키지명 차이(libreoffice vs libreoffice-fresh)는 adapter가 흡수

app_install_libreoffice() {
    proot_pkg_update
    proot_dep "libreoffice"
    proot_setup_bwrap
    desktop_copy_from_proot "libreoffice"
}

app_remove_libreoffice() {
    proot_dep_remove "libreoffice" 2>/dev/null || true
    proot_pkg_autoremove
    desktop_remove_prefix "libreoffice"
}

app_is_installed_libreoffice() {
    desktop_is_registered "libreoffice-base"
}
