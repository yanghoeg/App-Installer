#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Miniforge3 — proot 내부 Python 환경
# python/pip 패키지명 차이는 adapter가 흡수

# 버전 핀 + sha256 (releases/latest 대신 고정 태그) — 업스트림 .sha256 에셋과 대조해 갱신할 것.
_MINIFORGE_VER="26.5.3-0"
_MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/download/${_MINIFORGE_VER}/Miniforge3-${_MINIFORGE_VER}-Linux-aarch64.sh"
_MINIFORGE_SHA256="0391e42075a7632e9665d6e728387ee6b905f6c3e704d3513e1c1133d0d69b89"

app_install_miniforge() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    if app_is_installed_miniforge; then
        echo '[Miniforge] 이미 설치되어 있습니다.'
        return 0
    fi
    proot_pkg_update || return 1
    proot_pkg_install wget || return 1
    proot_pkg_install_python_pip || return 1

    proot_exec bash -c "$(fetch_verified_src)"$'\n''
        set -eu
        prefix="$HOME/miniforge3"
        stage=$(mktemp -d "${TMPDIR:-/tmp}/miniforge-install.XXXXXX")
        backup=""; started=false
        cleanup() {
            local rc=$?
            trap - EXIT
            if [ "$rc" -ne 0 ] && [ "$started" = true ]; then
                rm -rf -- "$prefix" || {
                    echo "[ERROR] Miniforge 임시 설치 정리 실패 (기존 백업: $backup)" >&2
                    rm -rf -- "$stage" || true
                    exit "$rc"
                }
                if [ -n "$backup" ]; then
                    mv -- "$backup" "$prefix" || echo "[ERROR] Miniforge 복구 실패: $backup" >&2
                fi
            fi
            rm -rf -- "$stage" || true
            exit "$rc"
        }
        trap cleanup EXIT
        # Finish the verified download before disturbing an existing prefix.
        fetch_verified "$1" "$stage/installer.sh" "$2"
        if [ -e "$prefix" ] || [ -L "$prefix" ]; then
            backup=$(mktemp -d "$HOME/.miniforge3-backup.XXXXXX")
            rmdir -- "$backup"
            mv -- "$prefix" "$backup"
        fi
        started=true
        bash "$stage/installer.sh" -b -p "$prefix"
        test -x "$prefix/bin/conda"
        test -x "$prefix/bin/python"
        test -f "$prefix/conda-meta/history"
        "$prefix/bin/conda" --version >/dev/null
        "$prefix/bin/python" --version >/dev/null
        # A damaged prefix can still contain user environments; keep its backup.
        [ -z "$backup" ] || printf "[Miniforge] 기존 prefix 백업: %s\n" "$backup"
    ' _ "$_MINIFORGE_URL" "$_MINIFORGE_SHA256" || { echo "[ERROR] Miniforge 다운로드/설치 실패" >&2; return 1; }
}

app_remove_miniforge() {
    rm -rf "$(_proot_rootfs)/home/${PROOT_USER}/miniforge3"
}

app_is_installed_miniforge() {
    local miniforge_dir
    miniforge_dir="$(_proot_rootfs)/home/${PROOT_USER}/miniforge3"
    [ -x "$miniforge_dir/bin/conda" ] && [ -x "$miniforge_dir/bin/python" ] &&
        [ -f "$miniforge_dir/conda-meta/history" ] || return 1
    proot_exec bash -c '"$HOME/miniforge3/bin/conda" --version >/dev/null 2>&1 &&
        "$HOME/miniforge3/bin/python" --version >/dev/null 2>&1'
}
