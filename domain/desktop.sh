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

# Unwrap only the shell form emitted by older installers. Never evaluate it.
_desktop_proot_exec() {
    local cmd="$1" quoted="$2" body label_pattern
    case "$cmd" in
        prun-gui\ *) printf '%s' "$cmd"; return 0 ;;
        prun\ *) cmd="${cmd#prun }" ;;
        'bash -c "prun '*)
            body="${cmd#bash -c \"}"
            [ "${body%\"}" != "$body" ] || return 1
            body="${body%\"}"
            case "$body" in
                *' </dev/null >/dev/null 2>&1 &') body="${body%' </dev/null >/dev/null 2>&1 &'}" ;;
                *' &') body="${body%' &'}" ;;
                *) return 1 ;;
            esac
            cmd="${body#prun }"
            # Shell quoting and operators cannot safely be copied as Exec syntax.
            case "$cmd" in *[\"\'\\\$\`\;\&\|\<\>\(\)]*) return 1 ;; esac
            ;;
        'bash -c "prun-gui '*)
            body="${cmd#bash -c \"}"
            [ "${body%\"}" != "$body" ] || return 1
            body="${body%\"}"
            case "$body" in
                *' </dev/null >/dev/null 2>&1 &') body="${body%' </dev/null >/dev/null 2>&1 &'}" ;;
                *' &') body="${body%' &'}" ;;
                *) return 1 ;;
            esac
            label_pattern="^prun-gui ('[^']*'|\"[^\"]*\"|[^[:space:]]+) -- (.+)$"
            [[ "$body" =~ $label_pattern ]] || return 1
            cmd="${BASH_REMATCH[2]}"
            case "$cmd" in *[\"\'\\\$\`\;\&\|\<\>\(\)]*) return 1 ;; esac
            ;;
    esac
    [ -n "$cmd" ] || return 1
    printf 'prun-gui %s -- %s' "$quoted" "$cmd"
}

# $2: name used in warnings (defaults to the file; imports pass their source).
desktop_rewrite_for_proot() {
    local file="$1" label="${2:-$1}" name=App line content='' quoted cmd stage target
    [ -f "$file" ] && [ -r "$file" ] || return 1
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in Name=*) name="${line#Name=}"; break ;; esac
    done < "$file" || return 1
    # A literal percent in the display name must not become an Exec field code.
    quoted=$(_desktop_exec_quote "${name//%/%%}")
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            Exec=*)
                cmd=$(_desktop_proot_exec "${line#Exec=}" "$quoted") || {
                    echo "[WARN] 안전하게 변환할 수 없는 proot 런처: $label" >&2
                    return 1
                }
                line="Exec=$cmd"
                ;;
            TryExec=*|Path=*) continue ;; # Container paths are not host paths.
            DBusActivatable=*) line=DBusActivatable=false ;;
        esac
        content+="$line"$'\n'
    done < "$file" || return 1
    # An unchanged launcher keeps its inode, links and Xfce trust checksum.
    printf '%s' "$content" | cmp -s - "$file" && return 0
    # Replace the link target so a linked desktop icon stays a link.
    target=$(readlink -f -- "$file") || return 1
    stage=$(mktemp "${target}.XXXXXX") || return 1
    if ! cp -p -- "$target" "$stage" || ! printf '%s' "$content" > "$stage" ||
       ! mv -f -- "$stage" "$target"; then
        rm -f -- "$stage"
        return 1
    fi
}

# Migrate launchers that still run prun directly. A launcher already using
# prun-gui, in any form, is left as it is: rewriting it would change the
# checksum behind its Xfce trust mark.
desktop_migrate_proot_launcher() {
    local file="$1" line legacy=false
    [ -f "$file" ] && [ -r "$file" ] || return 1
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            Exec=*prun-gui*) return 0 ;;
            Exec=prun\ *|'Exec=bash -c "prun '*) legacy=true ;;
        esac
    done < "$file" || return 1
    [ "$legacy" = false ] || desktop_rewrite_for_proot "$file"
}

# Resolve symlinks with container / as the root, including parent directories.
desktop_resolve_proot_source() {
    local file="$1" rootfs="${2%/}" path part target source links=0
    case "$file" in "$rootfs"/*) path="${file#"$rootfs"/}" ;; *) return 1 ;; esac
    source="$rootfs"
    while [ -n "$path" ]; do
        part="${path%%/*}"
        if [[ "$path" == */* ]]; then path="${path#*/}"; else path=''; fi
        case "$part" in
            ''|.) continue ;;
            ..) [ "$source" = "$rootfs" ] || source="${source%/*}"; continue ;;
        esac
        if [ -L "$source/$part" ]; then
            links=$((links + 1))
            [ "$links" -le 40 ] || return 1
            target=$(readlink -- "$source/$part") || return 1
            case "$target" in
                # proot's link2symlink stores hard links as host paths in the rootfs.
                "$rootfs"/*) source="$rootfs"; target="${target#"$rootfs"/}" ;;
                /*) source="$rootfs"; target="${target#/}" ;;
            esac
            path="$target${path:+/$path}"
        else
            source="$source/$part"
        fi
    done
    [ -f "$source" ] && [ -r "$source" ] || return 1
    printf '%s\n' "$source"
}

# Stage the entire import so failed reads, copies or rewrites preserve the menu.
desktop_import_proot() {
    local file="$1" rootfs="$2" destination="$3" source stage
    case "$file" in
        "$rootfs"/*) source=$(desktop_resolve_proot_source "$file" "$rootfs") || return 1 ;;
        *) source="$file" ;;
    esac
    [ -f "$source" ] && [ -r "$source" ] || return 1
    mkdir -p -- "${destination%/*}" || return 1
    stage=$(mktemp "${destination%/*}/.desktop-import.XXXXXX") || return 1
    if ! cp -p -- "$source" "$stage" || ! desktop_rewrite_for_proot "$stage" "$file" ||
       ! mv -f -- "$stage" "$destination"; then
        rm -f -- "$stage"
        return 1
    fi
}

# .desktop 파일 등록 (Termux apps 메뉴 + Desktop)
# $1=app_id  $2=name  $3=exec_cmd  $4=icon  $5=categories  [$6=extra_fields]
desktop_register() {
    local app_id="$1" name="$2" exec_cmd="$3" icon="$4" categories="$5"
    local extra="${6:-}"
    local desktop_file="${PREFIX}/share/applications/${app_id}.desktop"
    local shortcut="${HOME}/Desktop/${app_id}.desktop" stage shortcut_stage backup_stage target file
    local -a fields=(
        '[Desktop Entry]' 'Version=1.0' 'Type=Application' "Name=${name}"
        "Exec=${exec_cmd}" "Icon=${icon}" "Categories=${categories}"
        'Terminal=false' 'StartupNotify=false'
    )
    [ -z "$extra" ] || fields+=("$extra")

    mkdir -p "${PREFIX}/share/applications" "${HOME}/Desktop" || return 1
    [ ! -d "$desktop_file" ] && [ ! -d "$shortcut" ] || return 1
    stage=$(mktemp -d "${PREFIX}/share/applications/.desktop-register.XXXXXX") || return 1
    # Keep each staged file on its destination filesystem so publication is a rename.
    shortcut_stage=$(mktemp -d "${HOME}/Desktop/.desktop-register.XXXXXX") || {
        rm -rf -- "$stage"
        return 1
    }
    if ! printf '%s\n' "${fields[@]}" > "$stage/menu" ||
       ! chmod 644 "$stage/menu" ||
       ! cp -- "$stage/menu" "$shortcut_stage/shortcut" ||
       ! chmod +x "$shortcut_stage/shortcut"; then
        rm -rf -- "$stage" "$shortcut_stage"
        return 1
    fi
    # Prepare both files and their backups before changing either launcher.
    for file in menu shortcut; do
        if [ "$file" = menu ]; then
            target="$desktop_file"; backup_stage="$stage"
        else
            target="$shortcut"; backup_stage="$shortcut_stage"
        fi
        if [ -e "$target" ] || [ -L "$target" ]; then
            if ! cp -a -- "$target" "$backup_stage/old-$file"; then
                rm -rf -- "$stage" "$shortcut_stage"
                return 1
            fi
        fi
    done
    if ! mv -f -- "$stage/menu" "$desktop_file" ||
       ! mv -f -- "$shortcut_stage/shortcut" "$shortcut"; then
        for file in menu shortcut; do
            if [ "$file" = menu ]; then
                target="$desktop_file"; backup_stage="$stage"
            else
                target="$shortcut"; backup_stage="$shortcut_stage"
            fi
            if [ -e "$backup_stage/old-$file" ] || [ -L "$backup_stage/old-$file" ]; then
                mv -f -- "$backup_stage/old-$file" "$target" || {
                    echo "[ERROR] 런처 복구 실패: $target (백업: $backup_stage/old-$file)" >&2
                    return 1
                }
            else
                rm -f -- "$target" || return 1
            fi
        done
        rm -rf -- "$stage" "$shortcut_stage"
        return 1
    fi
    rm -rf -- "$stage" "$shortcut_stage" || return 1
    gio set "$shortcut" metadata::trusted true 2>/dev/null || true
    return 0
}

# proot 내부 .desktop 파일을 Termux 메뉴로 복사 후 Exec 재작성
# $1=app_prefix (e.g. "libreoffice", "nautilus")
desktop_copy_from_proot() {
    local app_prefix="$1"
    local rootfs
    rootfs=$(_proot_rootfs) || return 1
    [ -n "$rootfs" ] && [ -d "$rootfs" ] || return 1
    local desktop fname copied=0

    mkdir -p "${PREFIX}/share/applications" || return 1
    for desktop in "${rootfs}/usr/share/applications"/${app_prefix}*.desktop; do
        [ -e "$desktop" ] || [ -L "$desktop" ] || continue
        fname="${desktop##*/}"
        # Skip an entry that cannot be imported (a dangling link, an empty Exec)
        # rather than stopping with the menu half imported.
        if desktop_import_proot "$desktop" "$rootfs" "${PREFIX}/share/applications/${fname}"; then
            copied=$((copied + 1))
        else
            echo "[WARN] 메뉴로 가져오지 못한 항목을 건너뜁니다: ${desktop#"$rootfs"}" >&2
        fi
    done
    # Fail, with nothing registered, only when no entry could be imported.
    [ "$copied" -gt 0 ]
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
