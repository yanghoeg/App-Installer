#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: desktop.sh — .desktop 파일 관리 유틸리티
# =============================================================================

# .desktop 파일 등록 (Termux apps 메뉴 + Desktop)
# $1=app_id  $2=name  $3=exec_cmd  $4=icon  $5=categories  [$6=extra_fields]
desktop_register() {
    local app_id="$1" name="$2" exec_cmd="$3" icon="$4" categories="$5"
    local extra="${6:-}"
    local desktop_file="${PREFIX}/share/applications/${app_id}.desktop"

    mkdir -p "${PREFIX}/share/applications" "${HOME}/Desktop"

    {
        echo "[Desktop Entry]"
        echo "Version=1.0"
        echo "Type=Application"
        echo "Name=${name}"
        echo "Exec=${exec_cmd}"
        echo "Icon=${icon}"
        echo "Categories=${categories}"
        echo "Terminal=false"
        echo "StartupNotify=false"
        [ -n "$extra" ] && echo "$extra"
    } > "$desktop_file"

    cp "$desktop_file" "${HOME}/Desktop/${app_id}.desktop"
    chmod +x "${HOME}/Desktop/${app_id}.desktop"
}

# proot 내부 .desktop 파일을 Termux 메뉴로 복사 후 Exec 재작성
# $1=app_prefix (e.g. "libreoffice", "nautilus")
desktop_copy_from_proot() {
    local app_prefix="$1"
    local rootfs="${PREFIX}/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}"

    mkdir -p "${PREFIX}/share/applications"
    for desktop in "${rootfs}/usr/share/applications"/${app_prefix}*.desktop; do
        [ -f "$desktop" ] || continue
        local fname
        fname=$(basename "$desktop")
        cp "$desktop" "${PREFIX}/share/applications/${fname}"
        sed -i \
            "s|^Exec=\(.*\)$|Exec=proot-distro login ${PROOT_DISTRO} --user ${PROOT_USER} --shared-tmp -- env DISPLAY=:1.0 \1|" \
            "${PREFIX}/share/applications/${fname}"
    done
}

desktop_remove() {
    local app_id="$1"
    rm -f "${HOME}/Desktop/${app_id}.desktop" \
          "${PREFIX}/share/applications/${app_id}.desktop"
}

# prefix로 시작하는 모든 .desktop 파일 삭제 (desktop_copy_from_proot 역방향)
# $1=prefix (e.g. "libreoffice", "nautilus")
desktop_remove_prefix() {
    local prefix="$1"
    rm -f "${HOME}/Desktop/${prefix}"*.desktop \
          "${PREFIX}/share/applications/${prefix}"*.desktop
}

desktop_is_registered() {
    local app_id="$1"
    [ -e "${PREFIX}/share/applications/${app_id}.desktop" ]
}
