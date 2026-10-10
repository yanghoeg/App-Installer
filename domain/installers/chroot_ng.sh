#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: chroot-ng — ptrace 없는 proot 대체 런타임 (Termux native 소스 빌드)
# sylirre/fake-chroot-ng (Apache-2.0). Box64와 같이 고정 커밋을 받아 해시를 대조한 뒤 빌드하고,
# 이 기기 판정(--probe)과 rootfs 실행 검사를 통과해야 설치한다.
# 설치만으로는 바뀌는 것이 없다: prun은 PRUN_RUNTIME=chroot-ng일 때만 이 런타임을 쓴다.

CHROOT_NG_REPO='https://github.com/sylirre/fake-chroot-ng.git'
CHROOT_NG_COMMIT='a41aa92e183adbb7806f269369393f229ccdba52'  # v1.1.0 이후 70커밋 (2026-10-04)

_chroot_ng_bin() { printf '%s/bin/chroot-ng\n' "$PREFIX"; }

# 고정 커밋을 <src>에 받아 빌드한다. 결과물은 <src>/build/chroot-ng.
_chroot_ng_build() {
    local src="$1"
    git -C "$src" init -q &&
        git -C "$src" fetch -q --depth 1 "$CHROOT_NG_REPO" "$CHROOT_NG_COMMIT" &&
        git -C "$src" checkout -q FETCH_HEAD || return 1
    if [ "$(git -C "$src" rev-parse HEAD)" != "$CHROOT_NG_COMMIT" ]; then
        echo "[ERROR] chroot-ng 소스 커밋 불일치: $CHROOT_NG_COMMIT 기대" >&2
        return 1
    fi
    make -C "$src" CC=clang -j"$(nproc)" >/dev/null
}

app_install_chroot_ng() {
    has_proot_distro || { echo '[ERROR] proot 환경이 필요합니다.' >&2; return 1; }
    termux_pkg_install clang make git || return 1

    local src bin
    src=$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/chroot-ng.XXXXXX") || return 1
    bin="$src/build/chroot-ng"
    if ! _chroot_ng_build "$src"; then
        rm -rf "$src"; echo '[ERROR] chroot-ng 빌드 실패' >&2; return 1
    fi
    # seccomp 필터와 실행 메모리 권한이 있어야 동작한다
    if ! "$bin" --probe 2>&1 | grep -q 'LIKELY VIABLE'; then
        rm -rf "$src"
        echo '[ERROR] 이 기기는 chroot-ng 판정(--probe)을 통과하지 못했습니다.' >&2
        return 1
    fi
    if ! "$bin" "$(_proot_rootfs)" /usr/bin/true 2>/dev/null; then
        rm -rf "$src"
        echo '[ERROR] chroot-ng로 rootfs의 /usr/bin/true를 실행하지 못했습니다.' >&2
        return 1
    fi
    install -m 755 "$bin" "$(_chroot_ng_bin)" || { rm -rf "$src"; return 1; }
    rm -rf "$src"
    echo '[OK] chroot-ng 설치 완료. 사용: PRUN_RUNTIME=chroot-ng prun <명령>'
    echo '     메뉴 앱까지 쓰려면 ~/.config/termux-xfce/config에 PRUN_RUNTIME="chroot-ng"을 추가하세요.'
}

app_remove_chroot_ng() {
    rm -f "$(_chroot_ng_bin)"
}

app_is_installed_chroot_ng() {
    [ -x "$(_chroot_ng_bin)" ]
}
