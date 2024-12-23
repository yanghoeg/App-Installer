#!/data/data/com.termux/files/usr/bin/bash

#This script installs aarch64 .tar.xz or .tar.gz into ubuntu proot /opt directory and creates a desktop and menu launcher

# Default values to edit
#Enter URL to appimage
url="https://github.com/ArmCord/ArmCord/releases/download/v3.2.7/ArmCord_3.2.7_arm64.deb"
#Enter name of app
appname="armcord"
#Enter path to icon or system icon name
#/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu
icon_path="discord"
#Enter Categories for .desktop
category="Network"
#Enter any dependencies
depends="libasound2 pulseaudio-module-jack pulseaudio"

#Do not edit below here unless required
# Process command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --install)
            install=true
            shift
            ;;
        --uninstall)
            uninstall=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ "$install" = true ]; then
    download="wget $url"
    install="prun sudo apt install -y "

    varname=$(basename $PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu/home/*)
    prun="proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0 $@"

    $prun $download
    $install $depends
    $install ./${url##*/}
    $prun rm ${url##*/}

    installed_dir="$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu/$dir"
    desktop_file="$HOME/Desktop/$appname.desktop"
    binary=$(find "$installed_dir" -type f -executable -print -quit)

    #If binary is different, specify it here after $installed_dir/ and use $alt_binary instead of $binary
    alt_binary="$installed_dir/"

    #If binary is sandboxed use $sandboxed at end of Exec command
    sandboxed="--no-sandbox"

#NOTE: Do not remove prun from Exec command
cat > "$desktop_file" <<EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=Discord
Comment=Discord
Exec=prun $appname $sandboxed
Icon=$icon_path
Categories=$category
Terminal=false
EOL

chmod +x "$desktop_file"
cp "$desktop_file" $HOME/../usr/share/applications
echo "Installation completed."

elif [ "$uninstall" = true ]; then
    echo "Uninstalling..."
    uninstall="prun sudo apt remove"
    $uninstall $appname -y
    desktop_file="$HOME/Desktop/$appname.desktop"
    rm "$desktop_file"
    rm "$PREFIX/share/applications/$appname.desktop"

    echo "Uninstallation completed."
else
    echo "No valid option provided. Use --install or --uninstall."
    exit 1
fi
