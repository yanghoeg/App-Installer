#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# TEST: lib/proot_path.sh — proot rootfs 레이아웃 자동 판별
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/.."
source "${SCRIPT_DIR}/framework.sh"
source "${APP_DIR}/lib/proot_path.sh"

describe "_proot_rootfs — proot 레이아웃 자동 판별"

_t_proot_rootfs_prefers_new() {
    local sb; sb=$(make_sandbox)
    export PREFIX="${sb}/usr" PROOT_DISTRO="ubuntu"
    local base="${PREFIX}/var/lib/proot-distro"
    mkdir -p "${base}/containers/ubuntu/rootfs"

    assert_eq "${base}/containers/ubuntu/rootfs" "$(_proot_rootfs)" \
        "신규 레이아웃이 있으면 containers/<distro>/rootfs를 반환해야 함"
    cleanup_sandbox "$sb"
}
it "신규 레이아웃이 있으면 containers/<distro>/rootfs를 반환한다" _t_proot_rootfs_prefers_new

_t_proot_rootfs_falls_back_legacy() {
    local sb; sb=$(make_sandbox)
    export PREFIX="${sb}/usr" PROOT_DISTRO="ubuntu"
    local base="${PREFIX}/var/lib/proot-distro"
    mkdir -p "${base}/installed-rootfs/ubuntu"

    assert_eq "${base}/installed-rootfs/ubuntu" "$(_proot_rootfs)" \
        "레거시 레이아웃만 있으면 installed-rootfs/<distro>로 폴백해야 함"
    cleanup_sandbox "$sb"
}
it "레거시 레이아웃만 있으면 installed-rootfs/<distro>로 폴백한다" _t_proot_rootfs_falls_back_legacy

_t_proot_rootfs_new_wins_both() {
    local sb; sb=$(make_sandbox)
    export PREFIX="${sb}/usr" PROOT_DISTRO="ubuntu"
    local base="${PREFIX}/var/lib/proot-distro"
    mkdir -p "${base}/containers/ubuntu/rootfs" "${base}/installed-rootfs/ubuntu"

    assert_eq "${base}/containers/ubuntu/rootfs" "$(_proot_rootfs)" \
        "두 레이아웃이 공존하면 신규를 우선해야 함"
    cleanup_sandbox "$sb"
}
it "두 레이아웃이 공존하면 신규를 우선한다" _t_proot_rootfs_new_wins_both

print_results
