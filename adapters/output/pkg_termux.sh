#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER: pkg_termux.sh — Termux native pkg 구현체
# =============================================================================

termux_pkg_install()      { pkg install -y "$@"; }
termux_pkg_remove()       { pkg uninstall -y "$@"; }
termux_pkg_is_installed() { pkg list-installed 2>/dev/null | grep -q "^${1}/"; }
