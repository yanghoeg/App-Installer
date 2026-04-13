#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: 1Password — proot 내부 설치
# Ubuntu: 공식 arm64 .deb / Arch: AUR 1password → adapter가 처리

_1PASSWORD_DEB_URL="https://downloads.1password.com/linux/debian/arm64/stable/1password-latest.deb"

app_install_onepassword() {
    proot_pkg_install_deb_or_aur "$_1PASSWORD_DEB_URL" "1password"

    desktop_register "1password" "1Password" \
        'bash -c "prun 1password --no-sandbox </dev/null >/dev/null 2>&1 &"' \
        "1password" "Office;Security;"
}

app_remove_onepassword() {
    proot_pkg_remove 1password 2>/dev/null || true
    desktop_remove "1password"
}

app_is_installed_onepassword() {
    desktop_is_registered "1password"
}
