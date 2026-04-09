#!/data/data/com.termux/files/usr/bin/bash

# =============================================================================
# App Installer — distro-aware (ubuntu / archlinux)
# PROOT_DISTRO, PROOT_USER 는 ~/.config/termux-xfce/config 에서 로드
# =============================================================================

# config 로드 (Termux_XFCE 설치 시 생성됨)
CONFIG_FILE="$HOME/.config/termux-xfce/config"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

# fallback: config 없으면 기존 방식으로 ubuntu 유저 탐지
PROOT_DISTRO="${PROOT_DISTRO:-ubuntu}"
if [ -z "${PROOT_USER:-}" ]; then
    PROOT_USER="$(basename "$PREFIX/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/"* 2>/dev/null || echo "")"
fi

# Get the absolute path for the script's directory
script_dir=$(realpath "$(dirname "$0")")

# -----------------------------------------------------------------------------
# 경로 정의
# -----------------------------------------------------------------------------
installed_rootfs_dir="$PREFIX/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home"
owncloud_desktop="$PREFIX/share/applications/owncloud.desktop"
tor_desktop="$PREFIX/share/applications/tor.desktop"
libreoffice_desktop="$PREFIX/share/applications/libreoffice-base.desktop"
code_desktop="$PREFIX/share/applications/code.desktop"
vlc_desktop="$PREFIX/share/applications/vlc.desktop"
notion_desktop="$PREFIX/share/applications/notion.desktop"
nautilus_desktop="$PREFIX/share/applications/nautilus.desktop"
thunderbird_desktop="$PREFIX/share/applications/thunderbird.desktop"
sasm_desktop="$PREFIX/share/applications/sasm.desktop"
wine_desktop="$PREFIX/share/applications/wine64.desktop"
onepassword_desktop="$PREFIX/share/applications/1password.desktop"
dbeaver_desktop="$PREFIX/share/applications/dbeaver.desktop"
thorium_desktop="$PREFIX/share/applications/thorium-browser.desktop"
burpsuite_desktop="$PREFIX/share/applications/burpsuite.desktop"
miniforge_desktop="$PREFIX/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}/home/${PROOT_USER}/miniforge3"

# proot-distro login 래퍼
_prun() {
    proot-distro login "${PROOT_DISTRO}" --user "${PROOT_USER}" --shared-tmp -- env DISPLAY=:1.0 "$@"
}

# -----------------------------------------------------------------------------
# 설치 상태 확인
# -----------------------------------------------------------------------------
check_burpsuite_installed()   { [ -e "$burpsuite_desktop" ]   && echo "Installed" || echo "Not Installed"; }
check_miniforge_installed()   { [ -d "$miniforge_desktop" ]   && echo "Installed" || echo "Not Installed"; }
check_owncloud_installed()    { [ -e "$owncloud_desktop" ]    && echo "Installed" || echo "Not Installed"; }
check_tor_browser_installed() { [ -e "$tor_desktop" ]         && echo "Installed" || echo "Not Installed"; }
check_libreoffice_installed() { [ -e "$libreoffice_desktop" ] && echo "Installed" || echo "Not Installed"; }
check_code_installed()        { [ -e "$code_desktop" ]        && echo "Installed" || echo "Not Installed"; }
check_vlc_installed()         { [ -e "$vlc_desktop" ]         && echo "Installed" || echo "Not Installed"; }
check_notion_installed()      { [ -e "$notion_desktop" ]      && echo "Installed" || echo "Not Installed"; }
check_nautilus_installed()    { [ -e "$nautilus_desktop" ]    && echo "Installed" || echo "Not Installed"; }
check_thunderbird_installed() { [ -e "$thunderbird_desktop" ] && echo "Installed" || echo "Not Installed"; }
check_sasm_installed()        { [ -e "$sasm_desktop" ]        && echo "Installed" || echo "Not Installed"; }
check_wine_installed()        { [ -e "$wine_desktop" ]        && echo "Installed" || echo "Not Installed"; }
check_onepassword_installed() { [ -e "$onepassword_desktop" ] && echo "Installed" || echo "Not Installed"; }
check_dbeaver_installed()     { [ -e "$dbeaver_desktop" ]     && echo "Installed" || echo "Not Installed"; }
check_thorium_installed()     { [ -e "$thorium_desktop" ]     && echo "Installed" || echo "Not Installed"; }

# -----------------------------------------------------------------------------
# 설치 함수
# -----------------------------------------------------------------------------
install_burpsuite()   { "$script_dir/install_burpsuite.sh";   zenity --info --title="Installation Complete" --text="burpsuite has been installed successfully."; }
install_owncloud()    { "$script_dir/install_owncloud.sh";    zenity --info --title="Installation Complete" --text="owncloud has been installed successfully."; }
install_tor_browser() { "$script_dir/install_tor_browser.sh"; zenity --info --title="Installation Complete" --text="Tor Browser has been installed successfully."; }
install_libreoffice() { "$script_dir/install_libreoffice.sh"; zenity --info --title="Installation Complete" --text="Libreoffice has been installed successfully."; }
install_code()        { "$script_dir/install_vscode.sh";      zenity --info --title="Installation Complete" --text="Visual Studio Code has been installed successfully."; }
install_miniforge()   { "$script_dir/install_miniforge.sh";   zenity --info --title="Installation Complete" --text="miniforge3 has been installed successfully."; }
install_vlc()         { "$script_dir/install_vlc.sh";         zenity --info --title="Installation Complete" --text="VLC has been installed successfully."; }
install_notion()      { "$script_dir/install_notion.sh";      zenity --info --title="Installation Complete" --text="Notion has been installed successfully."; }
install_nautilus()    { "$script_dir/install_nautilus.sh";    zenity --info --title="Installation Complete" --text="nautilus has been installed successfully."; }
install_thunderbird() { "$script_dir/install_thunderbird.sh"; zenity --info --title="Installation Complete" --text="thunderbird has been installed successfully."; }
install_sasm()        { "$script_dir/install_sasm.sh";        zenity --info --title="Installation Complete" --text="sasm has been installed successfully."; }
install_wine()        { "$script_dir/install_wine.sh";        zenity --info --title="설치 완료" --text="Wine (Box64 + Wine-Staging) 설치가 완료되었습니다."; }
install_onepassword() { "$script_dir/install_1password.sh" --install; zenity --info --title="Installation Complete" --text="1password has been installed successfully."; }
install_dbeaver()     { "$script_dir/install_dbeaver.sh" --install;   zenity --info --title="Installation Complete" --text="dbeaver has been installed successfully."; }
install_thorium()     { "$script_dir/install_thorium.sh" --install;   zenity --info --title="Installation Complete" --text="Thorium has been installed successfully."; }

# -----------------------------------------------------------------------------
# 제거 함수
# -----------------------------------------------------------------------------
remove_burpsuite() {
    if [ -e "$burpsuite_desktop" ]; then
        _prun sudo /opt/BurpSuiteCommunity/uninstall
        rm -f "$HOME/Desktop/burpsuite.desktop" "$burpsuite_desktop"
        zenity --info --title="Removal Complete" --text="burpsuite has been removed successfully."
    else
        zenity --error --title="Removal Error" --text="burpsuite is not installed."
    fi
}

remove_owncloud() {
    if [ -e "$owncloud_desktop" ]; then
        _prun sudo -S apt remove owncloud
        rm -f "$HOME/Desktop/owncloud.desktop" "$owncloud_desktop"
        zenity --info --title="Removal Complete" --text="owncloud has been removed successfully."
    else
        zenity --error --title="Removal Error" --text="owncloud is not installed."
    fi
}

remove_tor_browser() {
    if [ -e "$tor_desktop" ]; then
        _prun sudo apt purge firefox-esr -y
        _prun sudo add-apt-repository --remove ppa:mozillateam/ppa
        _prun sudo apt update
        _prun rm -rf tor-browser
        rm -f "$HOME/Desktop/tor.desktop" "$tor_desktop"
        zenity --info --title="Removal Complete" --text="Tor Browser has been removed successfully."
    else
        zenity --error --title="Removal Error" --text="Tor Browser is not installed."
    fi
}

remove_libreoffice() {
    if [ -e "$libreoffice_desktop" ]; then
        _prun sudo apt remove libreoffice -y
        _prun sudo apt autoremove -y
        rm -f "$PREFIX/share/applications/libreoffice"* "$libreoffice_desktop"
        zenity --info --title="Removal Complete" --text="Libreoffice has been removed successfully."
    else
        zenity --error --title="Removal Error" --text="Libreoffice is not installed."
    fi
}

remove_code() {
    if [ -e "$code_desktop" ]; then
        _prun sudo apt remove code -y
        _prun sudo apt autoremove -y
        rm -f "$HOME/Desktop/code.desktop" "$code_desktop"
        zenity --info --title="Removal Complete" --text="VS Code has been removed successfully."
    else
        zenity --error --title="Removal Error" --text="VS Code is not installed."
    fi
}

remove_miniforge() {
    if [ -d "$miniforge_desktop" ]; then
        _prun sudo rm -rf ~/miniforge3
        zenity --info --title="Removal Complete" --text="miniforge3 has been removed successfully."
    else
        zenity --error --title="Removal Error" --text="miniforge3 is not installed."
    fi
}

remove_vlc() {
    if [ -e "$vlc_desktop" ]; then
        _prun sudo apt remove vlc -y
        _prun sudo apt autoremove -y
        rm -f "$vlc_desktop"
        zenity --info --title="Removal Complete" --text="VLC has been removed successfully."
    else
        zenity --error --title="Removal Error" --text="VLC is not installed."
    fi
}

remove_notion() {
    if [ -e "$notion_desktop" ]; then
        _prun rm -rf notion
        rm -f "$HOME/Desktop/notion.desktop" "$notion_desktop"
        zenity --info --title="Removal Complete" --text="Notion has been removed successfully."
    else
        zenity --error --title="Removal Error" --text="Notion is not installed."
    fi
}

remove_nautilus() {
    if [ -e "$nautilus_desktop" ]; then
        _prun sudo apt purge nautilus
        rm -f "$HOME/Desktop/nautilus.desktop" "$nautilus_desktop"
        zenity --info --title="Removal Complete" --text="nautilus has been removed successfully."
    else
        zenity --error --title="Removal Error" --text="nautilus is not installed."
    fi
}

remove_thunderbird() {
    if [ -e "$thunderbird_desktop" ]; then
        apt purge thunderbird -y
        rm -f "$HOME/Desktop/thunderbird.desktop" "$thunderbird_desktop"
        zenity --info --title="Removal Complete" --text="thunderbird has been removed successfully."
    else
        zenity --error --title="Removal Error" --text="thunderbird is not installed."
    fi
}

remove_sasm() {
    if [ -e "$sasm_desktop" ]; then
        _prun sudo apt purge sasm\*
        rm -f "$HOME/Desktop/sasm.desktop" "$sasm_desktop"
        zenity --info --title="Removal Complete" --text="sasm has been removed successfully."
    else
        zenity --error --title="Removal Error" --text="sasm is not installed."
    fi
}

remove_wine() {
    if [ -e "$wine_desktop" ]; then
        if [ -n "${PROOT_DISTRO:-}" ] && [ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/${PROOT_DISTRO}" ]; then
            _prun sudo bash -c "
                rm -rf /opt/wine-staging
                for bin in wine wine64 wineboot winecfg wineserver msiexec regedit winetricks; do
                    rm -f /usr/local/bin/\$bin
                done
                apt remove -y box64 2>/dev/null || true
            " 2>/dev/null || true
        else
            rm -rf "$HOME/.wine-staging"
        fi
        rm -f "$wine_desktop" \
              "$PREFIX/share/applications/winecfg.desktop" \
              "$PREFIX/bin/wine"
        zenity --info --title="제거 완료" --text="Wine이 제거되었습니다."
    else
        zenity --error --title="오류" --text="Wine이 설치되지 않았습니다."
    fi
}

remove_onepassword() {
    if [ -e "$onepassword_desktop" ]; then
        "$script_dir/install_1password.sh" --uninstall
        zenity --info --title="Removal Complete" --text="1password has been removed successfully."
    else
        zenity --error --title="Removal Error" --text="1password is not installed."
    fi
}

remove_dbeaver() {
    if [ -e "$dbeaver_desktop" ]; then
        _prun sudo rm -f /usr/bin/dbeaver
        _prun sudo rm -rf /opt/dbeaver
        _prun sudo apt autoremove -y
        rm -f "$HOME/Desktop/dbeaver.desktop" "$dbeaver_desktop"
        zenity --info --title="Removal Complete" --text="dbeaver has been removed successfully."
    else
        zenity --error --title="Removal Error" --text="dbeaver is not installed."
    fi
}

remove_thorium() {
    if [ -e "$thorium_desktop" ]; then
        "$script_dir/install_thorium.sh" --uninstall
        zenity --info --title="Removal Complete" --text="Thorium has been removed successfully."
    else
        zenity --error --title="Removal Error" --text="Thorium is not installed."
    fi
}

# -----------------------------------------------------------------------------
# 메인 루프
# -----------------------------------------------------------------------------
export GTK_THEME=Adwaita:dark

while true; do
    burpsuite_status=$(check_burpsuite_installed)
    miniforge_status=$(check_miniforge_installed)
    owncloud_status=$(check_owncloud_installed)
    tor_browser_status=$(check_tor_browser_installed)
    libreoffice_status=$(check_libreoffice_installed)
    code_status=$(check_code_installed)
    vlc_status=$(check_vlc_installed)
    notion_status=$(check_notion_installed)
    nautilus_status=$(check_nautilus_installed)
    thunderbird_status=$(check_thunderbird_installed)
    sasm_status=$(check_sasm_installed)
    wine_status=$(check_wine_installed)
    onepassword_status=$(check_onepassword_installed)
    dbeaver_status=$(check_dbeaver_installed)
    thorium_status=$(check_thorium_installed)

    _action() {
        local name="$1" status="$2" desc="$3"
        if [ "$status" = "Installed" ]; then
            echo "Remove ${name} (Status: Installed)|${desc}"
        else
            echo "Install ${name} (Status: Not Installed)|${desc}"
        fi
    }

    burpsuite_row=$(_action   "burpsuite"           "$burpsuite_status"   "A web hack application")
    miniforge_row=$(_action   "miniforge"            "$miniforge_status"   "miniforge3")
    owncloud_row=$(_action    "owncloud"             "$owncloud_status"    "A cloud storage client")
    tor_row=$(_action         "Tor Browser"          "$tor_browser_status" "A web browser for anonymous browsing")
    libreoffice_row=$(_action "Libreoffice"          "$libreoffice_status" "A free office productivity suite")
    code_row=$(_action        "Visual Studio Code"   "$code_status"        "Code Editing. Redefined.")
    vlc_row=$(_action         "VLC"                  "$vlc_status"         "A free cross-platform multimedia player")
    notion_row=$(_action      "Notion"               "$notion_status"      "A productivity and note-taking app")
    nautilus_row=$(_action    "nautilus"             "$nautilus_status"    "A Linux file manager")
    thunderbird_row=$(_action "thunderbird"          "$thunderbird_status" "A mail client")
    sasm_row=$(_action        "sasm"                 "$sasm_status"        "Simple assembler IDE")
    wine_row=$(_action        "Wine (Box64+Staging)"  "$wine_status"        "Windows 앱 실행 (Box64 + Wine-Staging)")
    onepassword_row=$(_action "1password"            "$onepassword_status" "Go ahead. Forget your passwords.")
    dbeaver_row=$(_action     "Dbeaver"              "$dbeaver_status"     "Universal database client")
    thorium_row=$(_action     "Thorium"              "$thorium_status"     "The fastest browser on Earth")

    _row() { local r="$1"; echo "FALSE" "${r%%|*}" "${r##*|}"; }

    choice=$(zenity --list --radiolist \
        --title="App Installer (proot: ${PROOT_DISTRO:-none}, user: ${PROOT_USER:-})" \
        --text="Select an action:" \
        --column="Select" --column="Action" --column="Description" \
        $(_row "$burpsuite_row") \
        $(_row "$miniforge_row") \
        $(_row "$owncloud_row") \
        $(_row "$tor_row") \
        $(_row "$libreoffice_row") \
        $(_row "$code_row") \
        $(_row "$vlc_row") \
        $(_row "$notion_row") \
        $(_row "$nautilus_row") \
        $(_row "$thunderbird_row") \
        $(_row "$sasm_row") \
        $(_row "$onepassword_row") \
        $(_row "$wine_row") \
        $(_row "$dbeaver_row") \
        $(_row "$thorium_row") \
        --width=900 --height=500) || exit 0

    [ -z "$choice" ] && exit 0

    case "$choice" in
        "${burpsuite_row%%|*}")
            [ "$burpsuite_status" = "Installed" ] && remove_burpsuite || install_burpsuite ;;
        "${miniforge_row%%|*}")
            [ "$miniforge_status" = "Installed" ] && remove_miniforge || install_miniforge ;;
        "${owncloud_row%%|*}")
            [ "$owncloud_status" = "Installed" ] && remove_owncloud || install_owncloud ;;
        "${tor_row%%|*}")
            [ "$tor_browser_status" = "Installed" ] && remove_tor_browser || install_tor_browser ;;
        "${libreoffice_row%%|*}")
            [ "$libreoffice_status" = "Installed" ] && remove_libreoffice || install_libreoffice ;;
        "${code_row%%|*}")
            [ "$code_status" = "Installed" ] && remove_code || install_code ;;
        "${vlc_row%%|*}")
            [ "$vlc_status" = "Installed" ] && remove_vlc || install_vlc ;;
        "${notion_row%%|*}")
            [ "$notion_status" = "Installed" ] && remove_notion || install_notion ;;
        "${nautilus_row%%|*}")
            [ "$nautilus_status" = "Installed" ] && remove_nautilus || install_nautilus ;;
        "${thunderbird_row%%|*}")
            [ "$thunderbird_status" = "Installed" ] && remove_thunderbird || install_thunderbird ;;
        "${sasm_row%%|*}")
            [ "$sasm_status" = "Installed" ] && remove_sasm || install_sasm ;;
        "${wine_row%%|*}")
            [ "$wine_status" = "Installed" ] && remove_wine || install_wine ;;
        "${onepassword_row%%|*}")
            [ "$onepassword_status" = "Installed" ] && remove_onepassword || install_onepassword ;;
        "${dbeaver_row%%|*}")
            [ "$dbeaver_status" = "Installed" ] && remove_dbeaver || install_dbeaver ;;
        "${thorium_row%%|*}")
            [ "$thorium_status" = "Installed" ] && remove_thorium || install_thorium ;;
        *)
            zenity --error --title="Error" --text="Invalid choice." ;;
    esac
done
