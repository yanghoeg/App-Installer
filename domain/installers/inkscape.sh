#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Inkscape — Termux native (x11-repo)

app_install_inkscape() {
    termux_pkg_install inkscape
    desktop_register "inkscape" "Inkscape" "inkscape %U" "inkscape" \
        "Graphics;VectorGraphics;" \
        "MimeType=image/svg+xml;image/svg+xml-compressed;application/vnd.corel-draw;"
}

app_remove_inkscape() {
    termux_pkg_remove inkscape
    desktop_remove "inkscape"
}

app_is_installed_inkscape() {
    termux_pkg_is_installed inkscape && desktop_is_registered "inkscape"
}
