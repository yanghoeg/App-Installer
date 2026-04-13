#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ADAPTER: pkg_proot_base.sh — proot 실행 공통 구현 (Ubuntu/Arch 공유)
# =============================================================================
# pkg_ubuntu.sh / pkg_arch.sh 가 각각 source 하여 사용.
# 직접 source 하지 말 것 — DI 컨테이너(install.sh)는 distro 어댑터만 로드.

proot_exec() {
    proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" \
        --shared-tmp -- env DISPLAY="${DISPLAY:-:0.0}" "$@"
}

# proot 내부에 bwrap 스텁 설치 — GTK4 앱이 glycin(SVG 로더)을 쓸 때 필요
# bwrap는 user namespace가 필요하지만 proot에선 없음 → 스텁으로 샌드박스 없이 직접 exec
proot_setup_bwrap() {
    proot_exec sudo bash -c 'cat > /usr/local/bin/bwrap << '"'"'BWRAP_EOF'"'"'
#!/bin/bash
# proot용 bwrap 스텁 — 샌드박스 없이 명령 직접 실행
while [ "$#" -gt 0 ]; do
    case "$1" in
        --ro-bind|--bind|--dev-bind|--bind-try|--ro-bind-try|--dev-bind-try|--bind-data|--ro-bind-data|--symlink)
            shift 3 ;;
        --setenv)
            shift 3 ;;
        --proc|--dev|--tmpfs|--mqueue|--dir|--file|--chdir|--hostname|--uid|--gid|--unsetenv|--lock-file|--seccomp|--add-seccomp-fd|--block-fd|--userns-block-fd|--info-fd|--json-status-fd|--userns|--userns2|--pidns|--chmod)
            shift 2 ;;
        --unshare-all|--unshare-user|--unshare-user-try|--unshare-ipc|--unshare-pid|--unshare-net|--unshare-uts|--unshare-cgroup|--unshare-cgroup-try|--share-net|--clearenv|--die-with-parent|--as-pid-1|--new-session|--disable-userns|--assert-userns-disabled)
            shift ;;
        --) shift; break ;;
        *) break ;;
    esac
done
exec "$@"
BWRAP_EOF
chmod +x /usr/local/bin/bwrap'
}

proot_exec_wine() {
    proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" \
        --shared-tmp -- env \
            DISPLAY="${DISPLAY:-:0.0}" \
            MESA_LOADER_DRIVER_OVERRIDE=zink \
            TU_DEBUG=noconform \
            ZINK_DESCRIPTORS=lazy \
            MESA_NO_ERROR=1 \
        "$@"
}
