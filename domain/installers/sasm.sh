#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: SASM — proot 내부 어셈블러 IDE
# Ubuntu: sources.list codename 폴백 필요 → adapter가 처리
# Arch: AUR sasm → adapter가 처리

app_install_sasm() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    proot_pkg_install_sasm || return 1

    local rootfs="$(_proot_rootfs)"
    local bashrc="${rootfs}/home/${PROOT_USER}/.bashrc"
    grep -q "alias sasm=" "$bashrc" 2>/dev/null || \
        echo "alias sasm='QT_SCALE_FACTOR=2 sasm'" >> "$bashrc"

    desktop_register "sasm" "SASM" \
        'bash -c "prun env QT_SCALE_FACTOR=2 sasm </dev/null >/dev/null 2>&1 &"' \
        "sasm" "Development;"
}

app_remove_sasm() {
    local rootfs="$(_proot_rootfs)"
    local bashrc="${rootfs}/home/${PROOT_USER}/.bashrc"
    # Arch: 소스 빌드 → 직접 삭제 / Ubuntu: apt purge
    case "${PROOT_DISTRO:-}" in
        archlinux) proot_exec sudo rm -f /usr/local/bin/sasm || return 1 ;;
        *) proot_pkg_purge sasm || return 1 ;;
    esac
    if [ -f "$bashrc" ]; then sed -i '/alias sasm=/d' "$bashrc" || return 1; fi
    desktop_remove "sasm"
}

app_is_installed_sasm() {
    desktop_is_registered "sasm"
}
