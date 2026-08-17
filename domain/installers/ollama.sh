#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Ollama — Termux native (termux-main)
# 로컬 LLM 실행기 + serve 서비스/채팅 런처 정비.
# 모델은 멀티-GB이므로 자동으로 받지 않고, 채팅 런처가 필요 시 사용자에게 물어봄.
#
# ollama-backend-vulkan: Adreno Vulkan GPU 추론 백엔드. ollama가 런타임에 로드하며
# Vulkan 초기화에 실패하면 CPU로 폴백한다. GPU를 실제로 쓰려면 '시스템 → GPU 가속'
# (gpu_native)으로 mesa-vulkan-icd-freedreno / vulkan-loader-generic 이 먼저 깔려야 한다.

_PKGS_OLLAMA=(ollama ollama-backend-vulkan)

_OLLAMA_SERVE_BIN="$PREFIX/bin/ollama-serve"
_OLLAMA_CHAT_BIN="$PREFIX/bin/ollama-chat"
_OLLAMA_SERVE_DESKTOP="$PREFIX/share/applications/ollama-serve.desktop"
_OLLAMA_CHAT_DESKTOP="$PREFIX/share/applications/ollama-chat.desktop"

# serve 백그라운드 제어 래퍼 (start/stop/status) — termux는 termux-services 미사용이라
# runit 대신 레포 공통 패턴(nohup ... & disown)으로 데몬을 띄운다.
_ollama_write_serve() {
    cat > "$_OLLAMA_SERVE_BIN" << 'OEOF'
#!/data/data/com.termux/files/usr/bin/bash
# 사용법: ollama-serve [start|stop|status]  (기본 start)
LOG="$PREFIX/var/log/ollama.log"
_up() { curl -sf http://127.0.0.1:11434/api/version >/dev/null 2>&1; }
case "${1:-start}" in
    start)
        if _up; then echo "ollama 서버가 이미 실행 중입니다."; exit 0; fi
        mkdir -p "$(dirname "$LOG")"
        setsid nohup ollama serve </dev/null >"$LOG" 2>&1 &
        disown 2>/dev/null || true
        for _ in $(seq 1 20); do _up && break; sleep 0.5; done
        if _up; then echo "ollama 서버를 시작했습니다 (로그: $LOG)"; else
            echo "서버 시작 실패 — 로그 확인: $LOG" >&2; exit 1; fi
        ;;
    stop)
        if pkill -f "ollama serve"; then echo "ollama 서버를 중지했습니다.";
        else echo "실행 중인 서버가 없습니다."; fi
        ;;
    status)
        if _up; then echo "실행 중"; else echo "중지됨"; fi
        ;;
    *)
        echo "사용법: ollama-serve [start|stop|status]" >&2; exit 2
        ;;
esac
OEOF
    chmod +x "$_OLLAMA_SERVE_BIN"
}

# 터미널 채팅 런처 — serve 자동 기동 후 대화형 실행. 모델 없으면 물어보되 강제로 받지 않음.
_ollama_write_chat() {
    cat > "$_OLLAMA_CHAT_BIN" << 'CEOF'
#!/data/data/com.termux/files/usr/bin/bash
# 사용법: ollama-chat [모델]  (모델 생략 시 설치된 첫 모델 사용)
ollama-serve start || exit 1
MODEL="${1:-$(ollama list 2>/dev/null | awk 'NR==2 {print $1}')}"
if [ -z "$MODEL" ]; then
    echo "설치된 모델이 없습니다. 예) ollama pull qwen2.5:0.5b (소형) / llama3.2 (범용)"
    read -r -p "지금 받을 모델 이름 (엔터=건너뛰기): " MODEL
    [ -z "$MODEL" ] && exit 0
    ollama pull "$MODEL" || exit 1
fi
exec ollama run "$MODEL"
CEOF
    chmod +x "$_OLLAMA_CHAT_BIN"
}

_ollama_write_desktops() {
    mkdir -p "$PREFIX/share/applications"
    cat > "$_OLLAMA_CHAT_DESKTOP" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Ollama Chat
Comment=로컬 LLM과 터미널에서 대화 (Ollama)
Exec=xfce4-terminal --title="Ollama Chat" --command="ollama-chat"
Icon=utilities-terminal
Categories=Development;
Terminal=false
EOF
    cat > "$_OLLAMA_SERVE_DESKTOP" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Ollama 서버 시작
Comment=Ollama serve 데몬을 백그라운드로 시작
Exec=ollama-serve start
Icon=applications-system
Categories=Development;
Terminal=false
EOF
}

app_install_ollama() {
    if ! termux_pkg_install "${_PKGS_OLLAMA[@]}"; then
        # 패키지 목록이 오래되면 설치가 실패할 수 있음 → 목록 갱신 후 1회 재시도
        apt update -y >/dev/null 2>&1 || true
        termux_pkg_install "${_PKGS_OLLAMA[@]}" || return 1
    fi
    _ollama_write_serve
    _ollama_write_chat
    _ollama_write_desktops

    if ! app_is_installed_gpu_native 2>/dev/null; then
        echo "[Ollama] 힌트: GPU 추론을 쓰려면 '시스템 → GPU 가속'을 먼저 설치하세요."
    fi
}

app_remove_ollama() {
    "$_OLLAMA_SERVE_BIN" stop >/dev/null 2>&1 || true
    rm -f "$_OLLAMA_SERVE_BIN" "$_OLLAMA_CHAT_BIN" \
          "$_OLLAMA_SERVE_DESKTOP" "$_OLLAMA_CHAT_DESKTOP"
    # ollama-backend-vulkan 은 ollama 에 의존하므로 함께 제거된다
    termux_pkg_remove ollama
}

app_is_installed_ollama() {
    termux_pkg_is_installed ollama
}
