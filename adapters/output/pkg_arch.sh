#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER: pkg_arch.sh — proot Arch pacman 구현체
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/pkg_proot_base.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/build_box64.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/build_sasm.sh"

proot_pkg_install()      { proot_exec sudo pacman -S --noconfirm --needed "$@"; }
proot_pkg_remove() {
    # Query once; a missing target is already removed, but database/removal errors
    # must still reach the caller so it can retain the launchers.
    proot_exec sudo bash -c '
        set -eu
        installed=$(pacman -Qq) || exit $?
        targets=()
        for pkg in "$@"; do
            case $'"'"'\n'"'"'"$installed"$'"'"'\n'"'"' in
                *$'"'"'\n'"'"'"$pkg"$'"'"'\n'"'"'*) targets+=("$pkg") ;;
            esac
        done
        [ "${#targets[@]}" -eq 0 ] || exec pacman -Rns --noconfirm -- "${targets[@]}"
    ' _ "$@"
}
proot_pkg_purge()        { proot_pkg_remove "$@"; }
proot_pkg_update()       { proot_setup_sudo_path; proot_exec sudo pacman -Syu --noconfirm; }
proot_pkg_autoremove() {
    proot_exec sudo bash -c \
        'orphans=$(pacman -Qdtq 2>/dev/null) || true
         if [ -n "$orphans" ]; then pacman -Rns --noconfirm $orphans; fi'
}
proot_pkg_is_installed() { proot_exec pacman -Q "$1" &>/dev/null; }

proot_pkg_install_aur() {
    local pkg="$1"
    proot_exec bash -c '
        if ! command -v yay &>/dev/null; then
            sudo pacman -S --noconfirm --needed git base-devel
            git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
            cd /tmp/yay-bin && makepkg -si --noconfirm
            rm -rf /tmp/yay-bin
        fi
        yay -S --noconfirm --needed "$1"
    ' _ "$pkg"
}

proot_pkg_install_deb_or_aur() {
    local _deb_url="$1"  # Arch에서는 미사용
    local aur_pkg="$2"
    local _sha="${3:-}"  # Arch는 AUR 경로라 .deb sha256 미사용
    proot_pkg_install_aur "$aur_pkg"
}

# Arch에는 .deb 개념 없음 — AUR(proot_pkg_install_aur)을 쓸 것
proot_pkg_install_deb_url() {
    echo "[ERROR] Arch: .deb 직접 설치 미지원 — AUR을 사용하세요" >&2
    return 1
}

# Arch에는 APT 저장소 개념 없음 — no-op
proot_pkg_add_external_repo() {
    echo "[INFO] Arch: proot_pkg_add_external_repo 불필요 (no-op)" >&2
}

proot_pkg_install_libreoffice() { proot_pkg_install libreoffice-fresh; }
proot_pkg_remove_libreoffice()  { proot_pkg_remove libreoffice-fresh; }
proot_pkg_install_python_pip()  { proot_pkg_install python python-pip; }
proot_pkg_install_zlib()        { proot_pkg_install zlib; }

# Arch ARM lacks a maintained SASM package; build the pinned upstream release.
proot_pkg_install_sasm() {
    proot_pkg_install nasm qt5-base qt5-tools make gcc git || return 1
    proot_exec sudo bash -c "$(sasm_build_source_script)"
}

# Arch: code는 공식 repo 없음 → AUR visual-studio-code-bin
proot_pkg_install_vscode() { proot_pkg_install_aur visual-studio-code-bin; }
proot_pkg_remove_vscode() {
    if proot_pkg_is_installed visual-studio-code-bin; then
        proot_pkg_remove visual-studio-code-bin
    elif proot_pkg_is_installed code; then
        proot_pkg_remove code
    fi
}

proot_pkg_install_box64() {
    proot_pkg_install git cmake base-devel python || return 1
    proot_exec sudo bash -c "$(box64_build_source_script)"
}

proot_pkg_install_wine_mesa() {
    proot_pkg_install mesa vulkan-freedreno
}

proot_pkg_install_gpu_tools() { proot_pkg_install mesa-demos vulkan-tools; }
