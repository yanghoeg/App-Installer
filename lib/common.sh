#!/data/data/com.termux/files/usr/bin/bash
# Shared configuration loading and proot user detection.

_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${_COMMON_DIR}/lib/proot_path.sh"

# install.sh / app-install.sh 공용 — proot 내부 rootfs의 home/ 아래 첫 사용자 디렉토리를
# 탐지. PROOT_DISTRO가 비어있으면(native only) 즉시 "user"로 폴백하고, 있으면
# for 루프(파이프라인 없음 — pipefail 아래에서도 안전)로 첫 디렉토리를 찾는다.
_detect_proot_user() {
    if [ -z "${PROOT_DISTRO:-}" ]; then
        echo "user"
        return
    fi
    local home_dir="$(_proot_rootfs)/home"
    local d
    for d in "$home_dir"/*/; do
        [ -d "$d" ] || continue
        [ "${d%/}" != "$home_dir/alarm" ] || continue
        basename "$d"
        return
    done
    echo "user"
}

_load_app_config() {
    local config="$HOME/.config/termux-xfce/config"
    local distro_set="${PROOT_DISTRO+x}" distro="${PROOT_DISTRO-}"
    local user_set="${PROOT_USER+x}" user="${PROOT_USER-}"
    if [ -f "$config" ]; then
        source "$config" || return 1
    fi
    if [ -n "$distro_set" ]; then
        # A user recorded for another distro is not a default for this one.
        if [ -z "$user_set" ] && [ "$distro" != "${PROOT_DISTRO-}" ]; then
            unset PROOT_USER
        fi
        PROOT_DISTRO="$distro"
    fi
    [ -z "$user_set" ] || PROOT_USER="$user"
    PROOT_DISTRO="${PROOT_DISTRO-ubuntu}"
    PROOT_USER="${PROOT_USER:-$(_detect_proot_user)}"
}
