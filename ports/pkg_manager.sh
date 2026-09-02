#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# PORT: pkg_manager.sh — 패키지 관리 계약 정의
# =============================================================================
# 모든 함수는 adapters/output/ 어댑터에서 override 필수.
# 미구현 상태로 호출하면 즉시 오류를 반환한다.

# proot rootfs 경로 해석기(_proot_rootfs) 공용 로드
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/proot_path.sh"

_port_not_impl() { echo "[PORT] ${1}: 어댑터가 구현되지 않았습니다" >&2; return 1; }

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

# --- proot 확장 (distro별 구현 차이) ---

# AUR 설치: Ubuntu=apt 폴백, Arch=yay
proot_pkg_install_aur()  { _port_not_impl "proot_pkg_install_aur"; }

# .deb(Ubuntu) / AUR(Arch) 설치 | $1=deb_url $2=aur_pkg
proot_pkg_install_deb_or_aur() { _port_not_impl "proot_pkg_install_deb_or_aur"; }

# 외부 APT 저장소 추가 (Arch: no-op) | $1=name $2=gpg_key_url $3=sources_line
proot_pkg_add_external_repo()  { _port_not_impl "proot_pkg_add_external_repo"; }

# 앱별 패키지명이 distro마다 다른 경우
proot_pkg_install_libreoffice() { _port_not_impl "proot_pkg_install_libreoffice"; }
proot_pkg_remove_libreoffice()  { _port_not_impl "proot_pkg_remove_libreoffice"; }
proot_pkg_install_jdk()         { _port_not_impl "proot_pkg_install_jdk"; }
proot_pkg_install_python_pip()  { _port_not_impl "proot_pkg_install_python_pip"; }
proot_pkg_install_zlib()        { _port_not_impl "proot_pkg_install_zlib"; }
proot_pkg_install_sasm()        { _port_not_impl "proot_pkg_install_sasm"; }
proot_pkg_install_box64()       { _port_not_impl "proot_pkg_install_box64"; }
proot_pkg_install_wine_mesa()   { _port_not_impl "proot_pkg_install_wine_mesa"; }
# Tor Browser 실행 의존성(curl + dbus-glib) 설치 — 패키지명이 distro마다 다름
proot_pkg_install_tor_deps()    { _port_not_impl "proot_pkg_install_tor_deps"; }

# --- proot 환경 설정 ---
proot_setup_sudo_path()      { _port_not_impl "proot_setup_sudo_path"; }
proot_setup_bwrap()          { _port_not_impl "proot_setup_bwrap"; }
proot_pkg_install_vscode()   { _port_not_impl "proot_pkg_install_vscode"; }
proot_pkg_remove_vscode()    { _port_not_impl "proot_pkg_remove_vscode"; }

# --- Termux native ---
termux_pkg_install()      { _port_not_impl "termux_pkg_install"; }
termux_pkg_remove()       { _port_not_impl "termux_pkg_remove"; }
termux_pkg_is_installed() { _port_not_impl "termux_pkg_is_installed"; }
# termux_pkg_enable_repo <repo-pkg> — x11-repo / tur-repo / root-repo 활성화 (멱등)
termux_pkg_enable_repo()  { _port_not_impl "termux_pkg_enable_repo"; }
