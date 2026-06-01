#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: 1Password — proot 내부 설치
# arm64: GUI 미지원 → CLI(op)만 제공
# Ubuntu: 공식 apt repo / Arch: AUR 1password-cli

app_install_onepassword() {
    case "${PROOT_DISTRO:-}" in
        archlinux)
            proot_pkg_install_aur 1password-cli
            ;;
        *)
            # Ubuntu: 공식 apt repo → 1password-cli (arm64 GUI 미지원)
            proot_exec sudo bash -c "
                apt install -y gpg curl 2>/dev/null
                curl -sS https://downloads.1password.com/linux/keys/1password.asc \
                    | gpg --dearmor > /usr/share/keyrings/1password-archive-keyring.gpg
                echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/arm64 stable main' \
                    > /etc/apt/sources.list.d/1password.list
                apt update -qq
                apt install -y 1password-cli
            "
            ;;
    esac
    echo "[INFO] 1Password GUI는 arm64 미지원 — CLI(op) 설치됨"
    echo "[INFO] 사용법: prun op --help"
}

app_remove_onepassword() {
    case "${PROOT_DISTRO:-}" in
        archlinux)
            proot_pkg_remove 1password-cli 2>/dev/null || true
            ;;
        *)
            proot_pkg_remove 1password-cli 2>/dev/null || true
            proot_exec sudo rm -f /etc/apt/sources.list.d/1password.list \
                /usr/share/keyrings/1password-archive-keyring.gpg 2>/dev/null || true
            ;;
    esac
}

app_is_installed_onepassword() {
    proot_exec which op &>/dev/null
}
