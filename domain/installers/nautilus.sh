#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Nautilus — proot 내부 파일 관리자

app_install_nautilus() {
    proot_pkg_update
    proot_pkg_install nautilus
    proot_setup_bwrap
    desktop_register "nautilus" "Nautilus" \
        'bash -c "prun-gui Nautilus -- env XDG_SESSION_TYPE=x11 GSK_RENDERER=cairo GDK_RENDERING=image dbus-run-session -- nautilus </dev/null >/dev/null 2>&1 &"' \
        "org.gnome.Nautilus" "System;FileManager;"
}

app_remove_nautilus() {
    proot_pkg_purge nautilus 2>/dev/null || true
    desktop_remove "nautilus"
}

app_is_installed_nautilus() {
    desktop_is_registered "nautilus"
}
