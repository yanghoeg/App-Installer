#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER: pkg_arch.sh — proot Arch pacman 구현체
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/pkg_proot_base.sh"

proot_pkg_install()      { proot_exec sudo pacman -S --noconfirm --needed "$@"; }
proot_pkg_remove()       { proot_exec sudo pacman -Rns --noconfirm "$@"; }
proot_pkg_purge()        { proot_exec sudo pacman -Rns --noconfirm "$@"; }
proot_pkg_update()       { proot_exec sudo pacman -Sy --noconfirm; }
proot_pkg_autoremove() {
    proot_exec sudo bash -c \
        'orphans=$(pacman -Qdtq 2>/dev/null); [ -n "$orphans" ] && pacman -Rns --noconfirm $orphans || true'
}
proot_pkg_is_installed() { proot_exec pacman -Q "$1" &>/dev/null; }

proot_pkg_install_aur() {
    local pkg="$1"
    proot_exec bash -c "
        if ! command -v yay &>/dev/null; then
            sudo pacman -S --noconfirm --needed git base-devel
            git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
            cd /tmp/yay-bin && makepkg -si --noconfirm
            rm -rf /tmp/yay-bin
        fi
        yay -S --noconfirm --needed '${pkg}'
    "
}

proot_pkg_install_deb_or_aur() {
    local _deb_url="$1"  # Arch에서는 미사용
    local aur_pkg="$2"
    proot_pkg_install_aur "$aur_pkg"
}

# Arch에는 APT 저장소 개념 없음 — no-op
proot_pkg_add_external_repo() {
    echo "[INFO] Arch: proot_pkg_add_external_repo 불필요 (no-op)" >&2
}

proot_pkg_install_libreoffice() { proot_pkg_install libreoffice-fresh; }
proot_pkg_remove_libreoffice()  { proot_pkg_remove libreoffice-fresh; }
proot_pkg_install_jdk()         { proot_pkg_install jdk-openjdk; }
proot_pkg_install_python_pip()  { proot_pkg_install python python-pip; }
proot_pkg_install_zlib()        { proot_pkg_install zlib; }

# Arch: codename 없음 → AUR sasm
proot_pkg_install_sasm() { proot_pkg_install_aur sasm; }

proot_pkg_install_box64() {
    proot_exec sudo bash -c "
        pacman -S --noconfirm box64 2>/dev/null && exit 0

        # Chaotic-AUR 추가
        pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com 2>/dev/null || true
        pacman-key --lsign-key 3056513887B78AEB 2>/dev/null || true
        pacman -U --noconfirm \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' 2>/dev/null || true
        grep -q '\[chaotic-aur\]' /etc/pacman.conf 2>/dev/null || \
            printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' >> /etc/pacman.conf
        pacman -Sy --noconfirm box64 2>/dev/null || echo '[WARN] Box64 설치 실패'
    " 2>/dev/null || true
}

proot_pkg_install_wine_mesa() {
    proot_pkg_install \
        mesa vulkan-freedreno lib32-mesa 2>/dev/null || \
        echo "[WARN] Mesa 일부 패키지 실패"
}
