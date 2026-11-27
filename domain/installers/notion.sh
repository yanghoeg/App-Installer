#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Notion — Firefox web launcher (Termux native)

app_install_notion() {
    termux_pkg_enable_repo x11-repo || return 1
    termux_pkg_install firefox || return 1
    desktop_register "notion" "Notion" \
        "firefox --new-window https://www.notion.so" \
        "firefox" "Office;" || return 1
}

# Updating the launcher leaves any data in the old AppImage directory intact.
app_upgrade_notion() { app_install_notion; }

app_remove_notion() {
    # Current installs own only this launcher. Older installations used a
    # generic directory name that cannot identify who owns its contents.
    desktop_remove "notion"
}

app_is_installed_notion() {
    desktop_is_registered "notion"
}
