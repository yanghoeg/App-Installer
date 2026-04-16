#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# PORT: pkg_manager.sh — 패키지 관리 계약 정의
# =============================================================================
# 모든 함수는 adapters/output/ 어댑터에서 override 필수.
# 미구현 상태로 호출하면 즉시 오류를 반환한다.

_port_not_impl() { echo "[PORT] ${1}: 어댑터가 구현되지 않았습니다" >&2; return 1; }

# --- Termux native ---
termux_pkg_install()      { _port_not_impl "termux_pkg_install"; }
termux_pkg_remove()       { _port_not_impl "termux_pkg_remove"; }
termux_pkg_is_installed() { _port_not_impl "termux_pkg_is_installed"; }

# --- proot 실행 ---
proot_exec()             { _port_not_impl "proot_exec"; }
proot_exec_wine()        { _port_not_impl "proot_exec_wine"; }

# --- proot 기본 패키지 관리 ---
proot_pkg_install()      { _port_not_impl "proot_pkg_install"; }
proot_pkg_remove()       { _port_not_impl "proot_pkg_remove"; }
proot_pkg_purge()        { _port_not_impl "proot_pkg_purge"; }
proot_pkg_update()       { _port_not_impl "proot_pkg_update"; }
proot_pkg_autoremove()   { _port_not_impl "proot_pkg_autoremove"; }
proot_pkg_is_installed() { _port_not_impl "proot_pkg_is_installed"; }

# --- proot 의존성 해석 (distro별 패키지명 추상화) ---
# 도메인이 "jdk", "libreoffice" 같은 논리 이름으로 요청하면
# 어댑터가 distro에 맞는 실제 패키지명으로 변환하여 설치/제거
proot_dep()              { _port_not_impl "proot_dep"; }
proot_dep_remove()       { _port_not_impl "proot_dep_remove"; }

# --- proot 확장 (distro별 설치 전략이 근본적으로 다른 경우) ---
proot_pkg_install_aur()        { _port_not_impl "proot_pkg_install_aur"; }
proot_pkg_install_deb_or_aur() { _port_not_impl "proot_pkg_install_deb_or_aur"; }
proot_pkg_add_external_repo()  { _port_not_impl "proot_pkg_add_external_repo"; }

# 복잡한 빌드/설치 로직이 distro마다 완전히 다른 앱
proot_pkg_install_sasm()  { _port_not_impl "proot_pkg_install_sasm"; }
proot_pkg_install_box64() { _port_not_impl "proot_pkg_install_box64"; }

# --- proot 환경 설정 ---
proot_setup_bwrap()      { _port_not_impl "proot_setup_bwrap"; }

# --- proot 경로 헬퍼 ---
proot_rootfs() {
    echo "${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}"
}
proot_home() {
    echo "$(proot_rootfs)/home/${PROOT_USER}"
}
