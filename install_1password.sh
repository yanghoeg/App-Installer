#!/data/data/com.termux/files/usr/bin/bash

#This script installs aarch64 appimages into ubuntu proot /opt directory and creates a desktop and menu launcher

# Default values to edit
#Enter URL to appimage
url="https://downloads.1password.com/linux/tar/stable/aarch64/1password-latest.tar.gz"
#Enter name of app
appname="1password"
#Enter path to icon or system icon name
icon_path="1password"
#Enter Categories for .desktop
category="System"
#Enter any dependencies
depends=""


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
    strip="--strip-components=1"
    extract="tar -xzf ${url##*/} -C $appname $strip" #-xvf is tar.xz or -xzf if tar.gz 
    dir="/opt/$appname"

    varname=$(basename $PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu/home/*)
    prun="proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0 $@"

    $prun $download
    $prun mkdir -p $appname
    $prun $extract
    $prun mv $appname $dir
    $prun rm ${url##*/}

    installed_dir="$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu/$dir"
    desktop_file="$HOME/Desktop/$appname.desktop"
    binary=$(find "$installed_dir" -type f -executable -print -quit)

    #If binary is different, specify it here after $installed_dir/ and use $alt_binary instead of $binary
    alt_binary="1password"

    #If binary is sandboxed use $sandboxed at end of Exec command
    sandboxed="--no-sandbox"

#NOTE: Do not remove prun from Exec command
cat > "$desktop_file" <<EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=$appname
Comment=Web Browser
Exec=prun $installed_dir/$alt_binary $sandboxed
Icon=$icon_path
Categories=$category
Terminal=false
EOL

chmod +x "$desktop_file"
cp "$desktop_file" $HOME/../usr/share/applications
echo "Installation completed."

elif [ "$uninstall" = true ]; then
    echo "Uninstalling..."
    dir="/opt/$appname"
    installed_dir="$HOME/../usr/var/lib/proot-distro/installed-rootfs/ubuntu/$dir"
    rm -rf "$installed_dir"
    desktop_file="$HOME/Desktop/$appname.desktop"
    rm "$desktop_file"
    rm "$HOME/../usr/share/applications/$appname.desktop"

    echo "Uninstallation completed."
else
    echo "No valid option provided. Use --install or --uninstall."
    exit 1
fi
