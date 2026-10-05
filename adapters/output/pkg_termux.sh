#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER: pkg_termux.sh — Termux native pkg 구현체
# =============================================================================

termux_pkg_install()      { pkg install -y -o Dpkg::Options::="--force-confold" "$@"; }
termux_pkg_remove()       { pkg uninstall -y "$@"; }
termux_pkg_is_installed() {
    local state
    state=$(dpkg-query -W -f='${Status}' -- "$1" 2>/dev/null) || return 1
    # The desired selection may be "hold"; installed state and error flag decide.
    [ "${state#* }" = 'ok installed' ]
}

# 추가 저장소 활성화 (x11-repo / tur-repo / root-repo). 이미 있으면 no-op.
termux_pkg_enable_repo() {
    local repo="$1"
    termux_pkg_is_installed "$repo" && return 0
    termux_pkg_install "$repo"
}
