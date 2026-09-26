#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DOMAIN: desktop.sh — .desktop 파일 관리 유틸리티
# =============================================================================

# Quote one argument for Desktop Entry Exec (including its string escaping).
_desktop_exec_quote() {
    local arg="$1"
    arg="${arg//\\/\\\\\\\\}"
    arg="${arg//\"/\\\\\"}"
    arg="${arg//\$/\\\\\$}"
    arg="${arg//\`/\\\\\`}"
    printf '"%s"' "$arg"
}

# The command is already in Desktop Entry Exec syntax. Avoid bash -c so field
# codes and quoted arguments keep their meaning and no shell is involved.
desktop_register_proot() {
    local app_id="$1" name="$2" cmd="$3"
    shift 3
    desktop_register "$app_id" "$name" "prun-gui $(_desktop_exec_quote "${name//%/%%}") -- $cmd" "$@"
}

desktop_rewrite_for_proot() {
    local file="$1" name=App line content='' quoted
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in Name=*) name="${line#Name=}"; break ;; esac
    done < "$file"
    # A literal percent in the display name must not become an Exec field code.
    quoted=$(_desktop_exec_quote "${name//%/%%}")
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            Exec=*) line="Exec=prun-gui $quoted -- ${line#Exec=}" ;;
            TryExec=*|Path=*) continue ;; # Container paths are not host paths.
            DBusActivatable=*) line=DBusActivatable=false ;;
        esac
        content+="$line"$'\n'
    done < "$file"
    printf '%s' "$content" > "$file"
}

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
    gio set "${HOME}/Desktop/${app_id}.desktop" metadata::trusted true 2>/dev/null || true
}

# proot 내부 .desktop 파일을 Termux 메뉴로 복사 후 Exec 재작성
# $1=app_prefix (e.g. "libreoffice", "nautilus")
desktop_copy_from_proot() {
    local app_prefix="$1"
    local rootfs="$(_proot_rootfs)"

    mkdir -p "${PREFIX}/share/applications"
    for desktop in "${rootfs}/usr/share/applications"/${app_prefix}*.desktop; do
        [ -f "$desktop" ] || continue
        local fname
        fname=$(basename "$desktop")
        cp "$desktop" "${PREFIX}/share/applications/${fname}"
        desktop_rewrite_for_proot "${PREFIX}/share/applications/${fname}" || return 1
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

# 주의: .desktop 파일 존재 여부만 확인한다. installer는 설치 실패 시
# desktop_register를 호출하지 않아야만 이 검사가 정확해진다.
desktop_is_registered() {
    local app_id="$1"
    [ -e "${PREFIX}/share/applications/${app_id}.desktop" ]
}
