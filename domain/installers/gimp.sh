#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: GIMP — Termux native (x11-repo)

app_install_gimp() {
    termux_pkg_install gimp
    desktop_register "gimp" "GIMP" "gimp %U" "gimp" \
        "Graphics;2DGraphics;RasterGraphics;Photography;" \
        "MimeType=image/bmp;image/gif;image/jpeg;image/png;image/tiff;image/x-xcf;"
}

app_remove_gimp() {
    termux_pkg_remove gimp
    desktop_remove "gimp"
}

app_is_installed_gimp() {
    desktop_is_registered "gimp"
}
