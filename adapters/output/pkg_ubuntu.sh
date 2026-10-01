#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER: pkg_ubuntu.sh — proot Ubuntu apt 구현체
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/pkg_proot_base.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/build_box64.sh"

proot_pkg_install()      { proot_exec sudo apt install -y "$@"; }
_proot_ubuntu_remove() {
    proot_exec sudo bash -c '
        set -eu
        mode=$1; shift
        packages=$(dpkg-query -W -f='"'"'${binary:Package}\t${db:Status-Status}\n'"'"') || exit $?
        targets=()
        for pkg in "$@"; do
            while IFS=$'"'"'\t'"'"' read -r name state; do
                [ "$name" = "$pkg" ] || [ "${name%%:*}" = "$pkg" ] || continue
                case "$state" in
                    ""|not-installed) continue ;;
                    config-files) [ "$mode" = purge ] || continue ;;
                esac
                targets+=("$pkg")
                break
            done <<< "$packages"
        done
        [ "${#targets[@]}" -eq 0 ] || exec apt "$mode" -y -- "${targets[@]}"
    ' _ "$@"
}
proot_pkg_remove()       { _proot_ubuntu_remove remove "$@"; }
proot_pkg_purge()        { _proot_ubuntu_remove purge "$@"; }
proot_pkg_update()       { proot_setup_sudo_path; proot_exec sudo apt update; }
proot_pkg_autoremove()   { proot_exec sudo apt autoremove -y; }
proot_pkg_is_installed() { proot_exec dpkg -s "$1" &>/dev/null; }

proot_pkg_install_aur() {
    echo "[WARN] Ubuntu에는 AUR 없음, apt 폴백 시도: $*" >&2
    proot_pkg_install "$@"
}

# $3=sha256(선택) — 주어지면 apt install 전에 검증하고, 불일치 시 rc≠0 (포트 계약 참조).
proot_pkg_install_deb_or_aur() {
    local deb_url="$1"
    local deb="${deb_url##*/}"
    local sha="${3:-}"
    proot_exec bash -c "$(fetch_verified_src)"$'\n''
        set -e
        dst="${TMPDIR:-/tmp}/$2"
        fetch_verified "$1" "$dst" "$3"
        sudo apt install -y "$dst"
        rm -f "$dst"
    ' _ "$deb_url" "$deb" "$sha"
}

# 공식 apt repo에 없는 .deb를 URL로 직접 설치 (nimf 등).
# 각 인자는 "URL" 또는 "URL|sha256" — sha256이 주어지면 dpkg -i 전에 무결성을 검증하고,
# 불일치 시 받은 파일을 지운 뒤 그 항목을 설치하지 않으며 함수 전체가 rc≠0을 반환한다.
# (GitHub Releases 변조/오다운로드를 조용히 통과시키지 않는다 — 포트 계약 참조.)
# dpkg 의존성 실패는 apt-get install -f와 최종 상태/버전 검증이 성공할 때만 복구로 인정한다.
proot_pkg_install_deb_url() {
    proot_exec bash -c "$(fetch_verified_src)"$'\n''
        set -eu
        stage=$(mktemp -d "${TMPDIR:-/tmp}/app-debs.XXXXXX") || exit 1
        trap '\''rm -rf "$stage"'\'' EXIT
        packages=(); versions=(); architectures=()
        rc=0; index=0
        for entry in "$@"; do
            url="${entry%%|*}"; sha=""
            [ "$entry" = "$url" ] || sha="${entry#*|}"
            index=$((index + 1))
            mkdir -p "$stage/$index" || exit 1
            deb="$stage/$index/${url##*/}"
            fetch_verified "$url" "$deb" "$sha" || { rc=1; continue; }
            package=$(dpkg-deb -f "$deb" Package) &&
                version=$(dpkg-deb -f "$deb" Version) &&
                architecture=$(dpkg-deb -f "$deb" Architecture) || { rc=1; continue; }
            [ -n "$package" ] && [ -n "$version" ] && [ -n "$architecture" ] || { rc=1; continue; }
            packages+=("$package"); versions+=("$version"); architectures+=("$architecture")
            sudo dpkg -i "$deb" || echo "[WARN] ${deb##*/} dpkg 실패 — apt-get install -f와 설치 상태를 확인합니다." >&2
        done
        [ "${#packages[@]}" -gt 0 ] || exit "$rc"
        sudo apt-get install -f -y || exit 1
        for index in "${!packages[@]}"; do
            package="${packages[index]}"; architecture="${architectures[index]}"
            query="$package"
            [ "$architecture" = all ] || query="$package:$architecture"
            state=$(dpkg-query -W -f='\''${Status}|${Version}|${Architecture}'\'' "$query") || { rc=1; continue; }
            if [ "$state" != "install ok installed|${versions[index]}|$architecture" ]; then
                echo "[ERROR] .deb 설치 상태/버전 불일치: $query ($state)" >&2
                rc=1
            fi
        done
        exit "$rc"
    ' _ "$@"
}

proot_pkg_add_external_repo() {
    local name="$1" gpg_key_url="$2" sources_line="$3"
    proot_exec sudo bash -c '
        set -eu
        apt-get install -y ca-certificates gpg wget
        key_tmp=$(mktemp)
        keyring_tmp=$(mktemp)
        trap "rm -f \"$key_tmp\" \"$keyring_tmp\"" EXIT
        wget -qO "$key_tmp" "$1"
        gpg --dearmor --yes --output "$keyring_tmp" "$key_tmp"
        install -Dm644 "$keyring_tmp" "/usr/share/keyrings/$2.gpg"
        printf "%s\\n" "$3" > "/etc/apt/sources.list.d/$2.list"
        apt-get update
    ' _ "$gpg_key_url" "$name" "$sources_line"
}

proot_pkg_install_libreoffice() { proot_pkg_install libreoffice; }
proot_pkg_remove_libreoffice()  { proot_pkg_remove libreoffice; }


proot_pkg_install_vscode() {
    proot_pkg_add_external_repo "vscode" \
        "https://packages.microsoft.com/keys/microsoft.asc" \
        "deb [arch=arm64 signed-by=/usr/share/keyrings/vscode.gpg] https://packages.microsoft.com/repos/code stable main" || return 1
    proot_pkg_install code
}
proot_pkg_remove_vscode() { proot_pkg_remove code; }

proot_pkg_install_python_pip() { proot_pkg_install python3 python3-pip; }
proot_pkg_install_zlib()       { proot_pkg_install zlib1g-dev; }

proot_pkg_install_sasm() {
    proot_exec sudo apt-get update || return 1
    proot_exec sudo apt-get install -y sasm
}

# Build the pinned upstream ARM64 release; no third-party binary repository.
proot_pkg_install_box64() {
    proot_pkg_install git cmake build-essential pkg-config python3 file || return 1
    proot_exec sudo bash -c "$(box64_build_source_script)"
}

proot_pkg_install_wine_mesa() {
    proot_pkg_install \
        mesa-vulkan-drivers libgl1-mesa-dri libgles2 \
        libvulkan1
}

proot_pkg_install_gpu_tools() { proot_pkg_install mesa-utils vulkan-tools; }
