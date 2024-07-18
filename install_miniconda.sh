#!/data/data/com.termux/files/usr/bin/bash
varname=$(basename $PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu/home/*)

proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0 sudo apt update
proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0 wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-armv7l.sh
proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0 chmod +x ./Miniconda3-latest-Linux-armv7l.sh
proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0 bash ./Miniconda3-latest-Linux-armv7l.sh
proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0 source ~/.bashrc
proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0 conda update conda
proot-distro login ubuntu --user $varname --shared-tmp -- env DISPLAY=:1.0 rm ~/Miniconda3-latest-Linux-armv7l.sh
