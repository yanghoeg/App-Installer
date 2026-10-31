#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: DBeaver CE — proot 내부 설치
# The official Linux archive contains its own Java runtime.
_DBEAVER_VER="26.2.1"
_DBEAVER_URL="https://github.com/dbeaver/dbeaver/releases/download/${_DBEAVER_VER}/dbeaver-ce-${_DBEAVER_VER}-linux-aarch64.tar.gz"
_DBEAVER_SHA256="76fad1d9064d0edadadf7ac811b33b675eca797a108dc46a8e382da22399cc8e"

app_install_dbeaver() {
    has_proot_distro || { echo "[ERROR] proot 환경이 필요합니다" >&2; return 1; }
    proot_pkg_update || return 1

    proot_exec sudo bash -c "$(fetch_verified_src)"$'\n''
        set -eu
        # Stage on the destination filesystem so publication and rollback use rename.
        stage=$(mktemp -d /opt/.dbeaver-install.XXXXXX)
        link_stage=""
        published=false; link_published=false; had_link=false
        cleanup() {
            local rc=$?
            trap - EXIT
            if [ "$rc" -ne 0 ]; then
                if [ -e "$stage/previous" ] || [ -L "$stage/previous" ]; then
                    if ! rm -rf -- /opt/dbeaver || ! mv -- "$stage/previous" /opt/dbeaver; then
                        echo "[ERROR] DBeaver 복구 실패 (백업 유지): $stage/previous" >&2
                        exit "$rc"
                    fi
                elif [ "$published" = true ]; then
                    rm -rf -- /opt/dbeaver || exit "$rc"
                fi
                if [ "$link_published" = true ]; then
                    if [ "$had_link" = true ]; then
                        mv -fT -- "$link_stage/previous" /usr/bin/dbeaver || {
                            echo "[ERROR] DBeaver 링크 복구 실패 (백업 유지): $link_stage/previous" >&2
                            exit "$rc"
                        }
                    else
                        rm -f -- /usr/bin/dbeaver || exit "$rc"
                    fi
                fi
            fi
            rm -rf -- "$stage" || true
            [ -z "$link_stage" ] || rm -rf -- "$link_stage" || true
            exit "$rc"
        }
        trap cleanup EXIT
        trap "exit 130" INT
        trap "exit 143" TERM
        fetch_verified "$1" "$stage/archive.tar.gz" "$2"
        tar -xzf "$stage/archive.tar.gz" -C "$stage"
        test -x "$stage/dbeaver/dbeaver"
        link_stage=$(mktemp -d /usr/bin/.dbeaver-link.XXXXXX)
        if [ -e /usr/bin/dbeaver ] || [ -L /usr/bin/dbeaver ]; then
            cp -a -- /usr/bin/dbeaver "$link_stage/previous"
            had_link=true
        fi
        ln -s /opt/dbeaver/dbeaver "$link_stage/new"
        if [ -e /opt/dbeaver ] || [ -L /opt/dbeaver ]; then
            mv -- /opt/dbeaver "$stage/previous"
        fi
        published=true
        mv -T -- "$stage/dbeaver" /opt/dbeaver
        link_published=true
        mv -fT -- "$link_stage/new" /usr/bin/dbeaver
    ' _ "$_DBEAVER_URL" "$_DBEAVER_SHA256" || { echo "[ERROR] DBeaver 다운로드/설치 실패" >&2; return 1; }

    desktop_register_proot "dbeaver" "DBeaver" "/usr/bin/dbeaver" \
        "dbeaver" "Development;Database;" || return 1
}

app_remove_dbeaver() {
    if has_proot_distro; then
        proot_exec sudo bash -c 'set -e; rm -f /usr/bin/dbeaver; rm -rf /opt/dbeaver' || return 1
    fi
    desktop_remove "dbeaver"
}

app_is_installed_dbeaver() {
    desktop_is_registered "dbeaver"
}
