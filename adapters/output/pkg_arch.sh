#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER: pkg_arch.sh — proot Arch pacman 구현체
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/pkg_proot_base.sh"

# --- 기본 패키지 관리 ---
proot_pkg_install()      { proot_exec sudo pacman -S --noconfirm --needed "$@"; }
proot_pkg_remove()       { proot_exec sudo pacman -Rns --noconfirm "$@"; }
proot_pkg_purge()        { proot_exec sudo pacman -Rns --noconfirm "$@"; }
proot_pkg_update()       { proot_setup_sudo_path; proot_exec sudo pacman -Sy --noconfirm; }
proot_pkg_autoremove() {
    proot_exec sudo bash -c \
        'orphans=$(pacman -Qdtq 2>/dev/null); [ -n "$orphans" ] && pacman -Rns --noconfirm $orphans || true'
}
proot_pkg_is_installed() { proot_exec pacman -Q "$1" &>/dev/null; }

# --- 의존성 매핑 (논리명 → Arch 패키지명) ---
PROOT_DEP_MAP=(
    "jdk:jdk-openjdk"
    "python:python python-pip"
    "zlib:zlib"
    "tor_deps:curl dbus-glib"
    "libreoffice:libreoffice-fresh"
    "mesa_vulkan:mesa vulkan-freedreno lib32-mesa"
)

# --- 확장 설치 전략 ---
proot_pkg_install_aur() {
    local pkg="$1"
    proot_exec bash -c "
        if ! command -v paru &>/dev/null; then
            sudo pacman -S --noconfirm --needed git base-devel
            git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
            cd /tmp/paru-bin && makepkg -si --noconfirm
            rm -rf /tmp/paru-bin
        fi
        paru -S --noconfirm --needed '${pkg}'
    "
}

proot_pkg_install_deb_or_aur() {
    local _deb_url="$1"
    local aur_pkg="$2"
    proot_pkg_install_aur "$aur_pkg"
}

proot_pkg_add_external_repo() {
    echo "[INFO] Arch: proot_pkg_add_external_repo 불필요 (no-op)" >&2
}

# --- 복잡한 앱별 설치 ---

proot_pkg_install_sasm() {
    proot_exec sudo bash -c "
        pacman -S --noconfirm --needed nasm qt5-base qt5-tools make gcc git
        [ -f /usr/local/bin/sasm ] && exit 0
        git clone https://github.com/Dman95/SASM.git /tmp/sasm-src
        cd /tmp/sasm-src && qmake SASM.pro && make -j4
        cp sasm /usr/local/bin/sasm
        rm -rf /tmp/sasm-src
    "
}

proot_pkg_install_box64() {
    proot_exec sudo bash -c "
        pacman -S --noconfirm box64 2>/dev/null && exit 0

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
