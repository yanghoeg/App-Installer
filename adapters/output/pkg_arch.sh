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
    if proot_exec which box64 &>/dev/null; then
        echo "[Box64] 이미 설치되어 있습니다."
        return 0
    fi

    # chaotic-aur는 x86_64 전용 → ARM64 proot에서는 소스 빌드가 유일한 방법
    echo "[Box64] GitHub 소스에서 빌드 중... (수분 소요)"
    proot_exec sudo bash -c '
        set -e
        pacman -S --noconfirm --needed cmake gcc make git python
        rm -rf /tmp/box64-build
        git clone --depth 1 https://github.com/ptitSeb/box64.git /tmp/box64-build
        # Wine SharedUserData(0x7FFE0000) 충돌 방지: prereserve 영역 분할
        sed -i "s/{(void\*)0x7f000000, 0x03000000}, {0, 0}, {0, 0}}/{(void*)0x7f000000, 0x00FE0000}, {(void*)0x7FFF0000, 0x02010000}, {0, 0}, {0, 0}}/" /tmp/box64-build/src/tools/wine_tools.c
        cd /tmp/box64-build && mkdir build && cd build
        cmake .. -DARM_DYNAREC=ON -DNOLOADADDR=ON -DBAD_SIGNAL=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo
        make -j$(nproc)
        make install
        rm -rf /tmp/box64-build
    '

    if proot_exec which box64 &>/dev/null; then
        echo "[Box64] 설치 완료."
    else
        echo "[ERROR] Box64 설치 실패 — Wine 실행 불가" >&2
        return 1
    fi
}
