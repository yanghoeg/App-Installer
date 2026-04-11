#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Nautilus — proot 내부 파일 관리자

app_install_nautilus() {
    proot_pkg_update
    proot_pkg_install nautilus
    desktop_copy_from_proot "nautilus"
}

app_remove_nautilus() {
    proot_pkg_purge nautilus 2>/dev/null || true
    desktop_remove "nautilus"
}

app_is_installed_nautilus() {
    desktop_is_registered "nautilus"
}
