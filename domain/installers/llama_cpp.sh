#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: llama.cpp — Termux native (termux-main)
# GGUF 모델 직접 추론. CLI 전용이라 .desktop 런처는 생성하지 않는다.
#
# GPU 백엔드 주의(Adreno/Snapdragon): Vulkan(Turnip/clvk) 경로는 이 계열 기기에서
# KGSL 펜스 버그로 garbage 토큰을 낸다(개별 op는 통과하지만 전체 그래프 추론이 깨짐).
# 대신 벤더 네이티브 OpenCL 드라이버(/vendor/lib64/libOpenCL.so)로 우회하면 정상 + 빠르다
# (Adreno 750 기준 Qwen2.5 Q5_K_M: 0.5b~45 / 1.5b~21 / 3b~14 tok/s). 그래서 Vulkan 백엔드는
# 기본 설치하지 않고 OpenCL 백엔드만 깔고, GPU 실행은 llama-gpu 런처로 네이티브 OpenCL을 강제한다.
# 모델(GGUF)은 멀티-GB이므로 자동으로 받지 않고, llama-model-get 헬퍼로 필요 시 받는다.

_PKGS_LLAMA_CPP=(llama-cpp llama-cpp-backend-opencl)

_LLAMA_GPU_BIN="$PREFIX/bin/llama-gpu"
_LLAMA_MODEL_GET_BIN="$PREFIX/bin/llama-model-get"

# GPU 런처 — 네이티브 Qualcomm OpenCL을 강제해 Turnip/clvk(Vulkan) garbage를 우회한다.
_llama_write_gpu_launcher() {
    cat > "$_LLAMA_GPU_BIN" << 'GEOF'
#!/data/data/com.termux/files/usr/bin/bash
# llama-gpu — Adreno GPU 추론 (네이티브 Qualcomm OpenCL 강제)
# 이 기기의 Vulkan(Turnip/clvk) 경로는 KGSL 버그로 garbage → 벤더 OpenCL로 우회.
#   사용법: llama-gpu [llama-cli 인자...]              (기본 -ngl 99 전 레이어 오프로드)
#           LLAMA_GPU_BIN=llama-server llama-gpu ...   ← 서버로 실행
set -u

if [ ! -e /vendor/lib64/libOpenCL.so ]; then
    echo "[llama-gpu] 네이티브 OpenCL 드라이버(/vendor/lib64/libOpenCL.so)가 없습니다." >&2
    echo "            이 기기는 GPU 우회 경로를 쓸 수 없습니다. CPU로 실행하세요." >&2
    exit 1
fi

# /vendor/lib64/libOpenCL.so 는 드라이버가 아니라 ocl-icd 로더다. libOpenCL.so 이름만
# 벤더 로더로 리다이렉트하는 전용 디렉터리를 만들어, 나머지 라이브러리(특히 libc++)는
# Termux 것을 우선하도록 한다. (벤더는 Android libc++, Termux 바이너리는 libc++_shared —
# /vendor 를 앞에 두면 ABI 충돌로 크래시)
_icd="$HOME/.opencl-native-icd"
if [ ! -e "$_icd/libOpenCL.so" ]; then
    mkdir -p "$_icd"
    ln -sf /vendor/lib64/libOpenCL.so "$_icd/libOpenCL.so"
fi

# OPENCL_VENDOR_PATH 를 비워 Termux 의 clvk.icd(=Turnip)를 배제하고,
# ocl-icd 폴백이 벤더 로더(libOpenCL.so)를 열게 한다.
export OCL_ICD_VENDORS=
export OPENCL_VENDOR_PATH=
export LD_LIBRARY_PATH="$_icd:$PREFIX/lib:/system/lib64:/vendor/lib64:/system/vendor/lib64"

exec "${LLAMA_GPU_BIN:-llama-cli}" -ngl 99 "$@"
GEOF
    chmod +x "$_LLAMA_GPU_BIN"
}

# 모델 다운로드 헬퍼 — Qwen2.5-Instruct Q5_K_M GGUF (Adreno GPU 에 적당한 크기).
_llama_write_model_get() {
    cat > "$_LLAMA_MODEL_GET_BIN" << 'MEOF'
#!/data/data/com.termux/files/usr/bin/bash
# llama-model-get — 로컬 LLM GGUF 다운로드 (~/models)
# 사용법: llama-model-get [0.5b|1.5b|3b|3.5-2b|3.5-4b|hammer]   (기본 1.5b)
#   0.5b ~420MB / 1.5b ~1.3GB / 3b ~2.4GB (Qwen2.5-Instruct Q5_K_M)
#   3.5-2b ~1.5GB (Qwen3.5-2B Q6_K) / 3.5-4b ~2.6GB (Qwen3.5-4B Q4_K_M) — 최신 소형 dense
#   hammer ~1.9GB (Hammer2.1-3b Q4_K_M — 함수호출/툴콜 판단이 좋은 3B)
set -eu
DIR="$HOME/models"; mkdir -p "$DIR"
case "${1:-1.5b}" in
    0.5b) REPO="Qwen/Qwen2.5-0.5B-Instruct-GGUF"; F="qwen2.5-0.5b-instruct-q5_k_m.gguf" ;;
    1.5b) REPO="Qwen/Qwen2.5-1.5B-Instruct-GGUF"; F="qwen2.5-1.5b-instruct-q5_k_m.gguf" ;;
    3b)   REPO="Qwen/Qwen2.5-3B-Instruct-GGUF";   F="qwen2.5-3b-instruct-q5_k_m.gguf" ;;
    3.5-2b) REPO="unsloth/Qwen3.5-2B-GGUF"; F="Qwen3.5-2B-Q6_K.gguf" ;;
    3.5-4b) REPO="unsloth/Qwen3.5-4B-GGUF"; F="Qwen3.5-4B-Q4_K_M.gguf" ;;
    hammer) REPO="Nekuromento/Hammer2.1-3b-Q4_K_M-GGUF"; F="hammer2.1-3b-q4_k_m.gguf" ;;
    *) echo "사용법: llama-model-get [0.5b|1.5b|3b|3.5-2b|3.5-4b|hammer]" >&2; exit 2 ;;
esac
OUT="$DIR/$F"
if [ -f "$OUT" ]; then
    echo "이미 있음: $OUT"
else
    echo "다운로드: $F"
    curl -L -C - -o "$OUT" "https://huggingface.co/$REPO/resolve/main/$F" \
        || { echo "다운로드 실패: $F" >&2; exit 1; }
fi
echo "완료: $OUT"
echo "실행 예: llama-gpu -m \"$OUT\" -st -p \"대한민국의 수도는?\""
MEOF
    chmod +x "$_LLAMA_MODEL_GET_BIN"
}

app_install_llama_cpp() {
    termux_pkg_install "${_PKGS_LLAMA_CPP[@]}" || return 1
    _llama_write_gpu_launcher
    _llama_write_model_get

    if ! app_is_installed_gpu_native 2>/dev/null; then
        echo "[llama.cpp] 힌트: GPU 추론을 쓰려면 '시스템 → GPU 가속'을 먼저 설치하세요."
    fi
    echo "[llama.cpp] CPU: llama-cli / llama-server, GPU: llama-gpu (네이티브 OpenCL)."
    echo "[llama.cpp] 모델: llama-model-get [0.5b|1.5b|3b|3.5-2b|3.5-4b|hammer] 로 GGUF 다운로드 (3.5-*=최신 Qwen3.5 Q4, hammer=툴콜용 Hammer2.1-3b Q4)."
}

app_remove_llama_cpp() {
    rm -f "$_LLAMA_GPU_BIN" "$_LLAMA_MODEL_GET_BIN"
    # 백엔드 패키지는 llama-cpp 에 의존하므로 함께 제거된다
    termux_pkg_remove llama-cpp
}

app_is_installed_llama_cpp() {
    termux_pkg_is_installed llama-cpp
}
