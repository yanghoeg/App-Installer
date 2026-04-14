#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: SASM — proot 내부 어셈블러 IDE
# Ubuntu: sources.list codename 폴백 필요 → adapter가 처리
# Arch: AUR sasm → adapter가 처리

app_install_sasm() {
    proot_pkg_install_sasm

    local rootfs="${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}"
    local bashrc="${rootfs}/home/${PROOT_USER}/.bashrc"
    grep -q "alias sasm=" "$bashrc" 2>/dev/null || \
        echo "alias sasm='QT_SCALE_FACTOR=2 sasm'" >> "$bashrc"

    desktop_register "sasm" "SASM" \
        'bash -c "prun env QT_SCALE_FACTOR=2 sasm </dev/null >/dev/null 2>&1 &"' \
        "sasm" "Development;"
}

app_remove_sasm() {
    # Arch: 소스 빌드 → 직접 삭제 / Ubuntu: apt purge
    proot_exec sudo rm -f /usr/local/bin/sasm 2>/dev/null || true
    proot_pkg_purge sasm 2>/dev/null || true
    desktop_remove "sasm"
}

app_is_installed_sasm() {
    desktop_is_registered "sasm"
}
