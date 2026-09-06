#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# TEST: lib/proot_path.sh — proot rootfs 레이아웃 자동 판별
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/.."
source "${SCRIPT_DIR}/framework.sh"
source "${APP_DIR}/lib/proot_path.sh"
source "${APP_DIR}/lib/common.sh"

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

# =============================================================================
# L12 — _detect_proot_user 단일화 (lib/common.sh)
# =============================================================================
describe "_detect_proot_user — lib/common.sh 단일 구현"

_t_detect_proot_user_empty_distro() {
    local sb; sb=$(make_sandbox)
    export PREFIX="${sb}/usr" PROOT_DISTRO=""

    assert_eq "user" "$(_detect_proot_user)" \
        "PROOT_DISTRO가 비어있으면 user를 반환해야 함"
    cleanup_sandbox "$sb"
}
it "PROOT_DISTRO가 비어있으면 user를 반환한다" _t_detect_proot_user_empty_distro

_t_detect_proot_user_finds_first_home_dir() {
    local sb; sb=$(make_sandbox)
    export PREFIX="${sb}/usr" PROOT_DISTRO="ubuntu"
    local base="${PREFIX}/var/lib/proot-distro"
    mkdir -p "${base}/installed-rootfs/ubuntu/home/alice"

    assert_eq "alice" "$(_detect_proot_user)" \
        "home 아래 첫 디렉토리를 반환해야 함"
    cleanup_sandbox "$sb"
}
it "rootfs의 home 아래 alice가 있으면 alice를 반환한다" _t_detect_proot_user_finds_first_home_dir

_t_detect_proot_user_empty_home_dir() {
    local sb; sb=$(make_sandbox)
    export PREFIX="${sb}/usr" PROOT_DISTRO="ubuntu"
    local base="${PREFIX}/var/lib/proot-distro"
    mkdir -p "${base}/installed-rootfs/ubuntu/home"

    assert_eq "user" "$(_detect_proot_user)" \
        "home이 비어있으면 user로 폴백해야 함"
    cleanup_sandbox "$sb"
}
it "rootfs의 home이 비어있으면 user를 반환한다" _t_detect_proot_user_empty_home_dir

print_results
