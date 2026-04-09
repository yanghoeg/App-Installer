#!/data/data/com.termux/files/usr/bin/bash
# VLC — Termux native 패키지 (proot 불필요)
# desktop 파일은 pkg 설치 시 $PREFIX/share/applications/vlc.desktop 자동 생성됨

set -euo pipefail

pkg install -y vlc

# Termux에서 vlc는 pkg 설치 시 desktop 파일이 자동 생성되지 않음 → 직접 생성
mkdir -p "${PREFIX}/share/applications"
cat > "${PREFIX}/share/applications/vlc.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=VLC media player
Comment=Read, capture, broadcast your multimedia streams
Exec=vlc --started-from-file %f
Icon=vlc
Terminal=false
Categories=AudioVideo;Player;Recorder;
MimeType=video/mpeg;video/x-mpeg;video/msvideo;video/quicktime;video/x-avi;audio/mpeg;audio/x-mpeg;audio/x-wav;
EOF
