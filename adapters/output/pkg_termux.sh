#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER: pkg_termux.sh — Termux native pkg 구현체
# =============================================================================

termux_pkg_install()      { pkg install -y "$@"; }
termux_pkg_remove()       { pkg uninstall -y "$@"; }
termux_pkg_is_installed() { pkg list-installed 2>/dev/null | grep -q "^${1}/"; }

# 추가 저장소 활성화 (x11-repo / tur-repo / root-repo). 이미 있으면 no-op.
termux_pkg_enable_repo() {
    local repo="$1"
    termux_pkg_is_installed "$repo" && return 0
    termux_pkg_install "$repo"
}
