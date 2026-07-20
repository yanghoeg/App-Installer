#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# lib/proot_path.sh — proot-distro rootfs 경로 해석 (레이아웃 자동 판별)
# =============================================================================
#   신규:   $PREFIX/var/lib/proot-distro/containers/<distro>/rootfs   (Python proot-distro)
#   레거시: $PREFIX/var/lib/proot-distro/installed-rootfs/<distro>    (구 bash proot-distro)
# 이미 설치된 경우 실제 존재하는 경로를 우선하고, 미설치(설치 직전)에는
# proot-distro 구현으로 판별한다: Python 모듈이 있으면 신규, 없으면 레거시.
# 테스트/특수 환경은 PROOT_ROOTFS_BASE로 베이스 디렉토리를 override할 수 있다.

[ -n "${_PROOT_PATH_SH:-}" ] && return 0
_PROOT_PATH_SH=1

_proot_rootfs() {
    local distro="${1:-${PROOT_DISTRO:-}}"
    local base="${PROOT_ROOTFS_BASE:-$PREFIX/var/lib/proot-distro}"
    local new="${base}/containers/${distro}/rootfs"
    local legacy="${base}/installed-rootfs/${distro}"

    if [ -d "$new" ]; then
        printf '%s' "$new"
    elif [ -d "$legacy" ]; then
        printf '%s' "$legacy"
    elif command -v python3 >/dev/null 2>&1 && python3 -c 'import proot_distro' 2>/dev/null; then
        printf '%s' "$new"
    else
        printf '%s' "$legacy"
    fi
}
