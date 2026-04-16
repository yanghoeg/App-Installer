#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER: pkg_ubuntu.sh — proot Ubuntu apt 구현체
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/pkg_proot_base.sh"

# --- 기본 패키지 관리 ---
proot_pkg_install()      { proot_exec sudo apt install -y "$@"; }
proot_pkg_remove()       { proot_exec sudo apt remove -y "$@"; }
proot_pkg_purge()        { proot_exec sudo apt purge -y "$@"; }
proot_pkg_update()       { proot_setup_sudo_path; proot_exec sudo apt update; }
proot_pkg_autoremove()   { proot_exec sudo apt autoremove -y; }
proot_pkg_is_installed() { proot_exec dpkg -s "$1" &>/dev/null; }

# --- 의존성 매핑 (논리명 → Ubuntu 패키지명) ---
PROOT_DEP_MAP=(
    "jdk:openjdk-21-jdk"
    "python:python3 python3-pip"
    "zlib:zlib1g-dev"
    "tor_deps:curl libdbus-glib-1-2"
    "libreoffice:libreoffice"
    "mesa_vulkan:mesa-vulkan-drivers libgl1-mesa-dri libgles2-mesa libvulkan1 vulkan-tools"
)

# --- 확장 설치 전략 ---
proot_pkg_install_aur() {
    echo "[WARN] Ubuntu에는 AUR 없음, apt 폴백 시도: $*" >&2
    proot_pkg_install "$@"
}

proot_pkg_install_deb_or_aur() {
    local deb_url="$1"
    local deb="${deb_url##*/}"
    proot_exec bash -c "
        curl -fsSL '${deb_url}' -o /tmp/${deb}
        sudo apt install -y /tmp/${deb}
        rm -f /tmp/${deb}
    "
}

proot_pkg_add_external_repo() {
    local name="$1" gpg_key_url="$2" sources_line="$3"
    proot_exec sudo bash -c "
        apt install -y gpg software-properties-common apt-transport-https 2>/dev/null || true
        wget -qO- '${gpg_key_url}' | gpg --dearmor > /usr/share/keyrings/${name}.gpg
        echo '${sources_line}' > /etc/apt/sources.list.d/${name}.list
        apt update
    "
}

# --- 복잡한 앱별 설치 (빌드/설치 전략이 distro마다 근본적으로 다름) ---

proot_pkg_install_sasm() {
    local rootfs; rootfs="$(proot_rootfs)"
    local sources="${rootfs}/etc/apt/sources.list"

    proot_exec sudo bash -c "
        apt-get install -y software-properties-common 2>/dev/null || true
        add-apt-repository universe -y 2>/dev/null || true
        apt-get update
    "
    if proot_exec sudo apt-get install -y sasm 2>/dev/null; then
        return 0
    fi

    echo "[WARN] 현재 버전에서 sasm 미지원, jammy(22.04) 폴백 시도" >&2
    if [ -f "$sources" ]; then
        cp "$sources" "${sources}.bak"
        sed -i 's/noble/jammy/g; s/oracular/jammy/g; s/plucky/jammy/g; s/mantic/jammy/g' "$sources"
    fi

    proot_exec sudo apt update
    proot_exec sudo apt-get install -y sasm || \
        echo "[WARN] SASM 설치 실패 — arm64 바이너리 미지원 가능성 있음" >&2

    [ -f "${sources}.bak" ] && mv "${sources}.bak" "$sources"
    proot_exec sudo apt update
}

proot_pkg_install_box64() {
    local rootfs; rootfs="$(proot_rootfs)"
    local codename
    codename=$(grep "^VERSION_CODENAME=" "${rootfs}/etc/os-release" 2>/dev/null \
        | cut -d= -f2 | tr -d '"' || echo "jammy")

    local box64_tag
    box64_tag=$(curl -sf "https://api.github.com/repos/ptitSeb/box64/releases/latest" \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4 || echo "")

    if [ -n "$box64_tag" ]; then
        local box64_url="https://github.com/ptitSeb/box64/releases/download/${box64_tag}/box64_Ubuntu_${codename}_arm64.deb"
        proot_exec sudo bash -c "
            wget -q '${box64_url}' -O /tmp/box64.deb 2>/dev/null \
            && dpkg -i /tmp/box64.deb && rm -f /tmp/box64.deb
        " || proot_pkg_install box64 2>/dev/null || echo "[WARN] Box64 설치 실패"
    else
        proot_pkg_install box64 2>/dev/null || echo "[WARN] Box64 설치 실패"
    fi
}
