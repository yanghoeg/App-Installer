#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: VLC — proot 설치 (Termux 네이티브 빌드는 Qt GUI 없음 → ncurses/dummy만)

app_install_vlc() {
    proot_pkg_update
    proot_pkg_install vlc
    proot_setup_bwrap
    desktop_copy_from_proot "vlc"

    # proot에는 D-Bus 세션이 없어 VLC 기본 인터페이스(dbus,none)가 실패.
    # Qt를 명시해 메뉴 실행 시 GUI가 정상적으로 뜨게 한다.
    local vlc_desktop="${PREFIX}/share/applications/vlc.desktop"
    [ -f "$vlc_desktop" ] && sed -i 's|/usr/bin/vlc |/usr/bin/vlc --intf qt |' "$vlc_desktop"
}

app_remove_vlc() {
    proot_pkg_remove vlc 2>/dev/null || true
    proot_pkg_autoremove
    desktop_remove_prefix "vlc"
}

app_is_installed_vlc() {
    proot_pkg_is_installed vlc
}
