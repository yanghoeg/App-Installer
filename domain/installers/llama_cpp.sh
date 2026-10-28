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
    local staged
    staged=$(mktemp "$_LLAMA_GPU_BIN.tmp.XXXXXX") || return 1
    if ! cat > "$staged" << 'GEOF'; then
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

# 기본 컨텍스트 4096 — 미지정 시 모델 기본(Qwen3.5=262144)을 물려받아 KV 캐시가
# 수십 GB로 잡혀 OOM 으로 죽는다. -c/--ctx-size 를 직접 주면 그대로 존중한다.
# (KV 양자화 -ctk/-ctv 는 -fa 필수 → 이 Adreno OpenCL 백엔드에선 CPU 폴백으로
#  생성이 ~13배 느려지므로 쓰지 말고 컨텍스트로 조절할 것)
_ctx=()
case " $* " in
    *" -c "*|*" --ctx-size "*) : ;;
    *) _ctx=(-c "${LLAMA_CTX:-4096}") ;;
esac

exec "${LLAMA_GPU_BIN:-llama-cli}" -ngl 99 "${_ctx[@]}" "$@"
GEOF
        rm -f "$staged"
        return 1
    fi
    if ! chmod 755 "$staged" || ! mv -f "$staged" "$_LLAMA_GPU_BIN"; then
        rm -f "$staged"
        return 1
    fi
}

# 모델 다운로드 헬퍼 — Qwen2.5-Instruct Q5_K_M GGUF (Adreno GPU 에 적당한 크기).
_llama_write_model_get() {
    local staged
    staged=$(mktemp "$_LLAMA_MODEL_GET_BIN.tmp.XXXXXX") || return 1
    if ! cat > "$staged" << 'MEOF'; then
#!/data/data/com.termux/files/usr/bin/bash
# llama-model-get — 로컬 LLM GGUF 다운로드 (~/models)
# 사용법: llama-model-get [0.5b|1.5b|3b|3.5-2b|3.5-4b|hammer]   (기본 1.5b)
#   0.5b ~420MB / 1.5b ~1.3GB / 3b ~2.4GB (Qwen2.5-Instruct Q5_K_M)
#   3.5-2b ~1.4GB (Qwen3.5-2B Q5_K_M) / 3.5-4b ~2.6GB (Qwen3.5-4B Q4_K_M) — 최신 소형 dense
#   hammer ~1.9GB (Hammer2.1-3b Q4_K_M — 함수호출/툴콜 판단이 좋은 3B)
set -eu
DIR="$HOME/models"; mkdir -p "$DIR"
case "${1:-1.5b}" in
    0.5b) REPO="Qwen/Qwen2.5-0.5B-Instruct-GGUF"; F="qwen2.5-0.5b-instruct-q5_k_m.gguf" ;;
    1.5b) REPO="Qwen/Qwen2.5-1.5B-Instruct-GGUF"; F="qwen2.5-1.5b-instruct-q5_k_m.gguf" ;;
    3b)   REPO="Qwen/Qwen2.5-3B-Instruct-GGUF";   F="qwen2.5-3b-instruct-q5_k_m.gguf" ;;
    3.5-2b) REPO="unsloth/Qwen3.5-2B-GGUF"; F="Qwen3.5-2B-Q5_K_M.gguf" ;;
    3.5-4b) REPO="unsloth/Qwen3.5-4B-GGUF"; F="Qwen3.5-4B-Q4_K_M.gguf" ;;
    hammer) REPO="Nekuromento/Hammer2.1-3b-Q4_K_M-GGUF"; F="hammer2.1-3b-q4_k_m.gguf" ;;
    *) echo "사용법: llama-model-get [0.5b|1.5b|3b|3.5-2b|3.5-4b|hammer]" >&2; exit 2 ;;
esac
OUT="$DIR/$F"
PART="$OUT.part"
COMPLETE="$OUT.complete"
URL="https://huggingface.co/$REPO/resolve/main/$F"

# 같은 디렉터리에서 완성한 뒤 교체해 중단된 marker를 완료 증거로 쓰지 않는다.
write_complete() {
    local marker_tmp
    marker_tmp=$(mktemp "$COMPLETE.tmp.XXXXXX") || return 1
    if ! printf '%s\n%s\n%s\n' "$URL" "$1" "$2" > "$marker_tmp" || ! mv "$marker_tmp" "$COMPLETE"; then
        rm -f "$marker_tmp"
        return 1
    fi
}

file_sha256() {
    local digest
    digest=$(sha256sum < "$1") || return 1
    printf '%s\n' "${digest%% *}"
}

show_complete() {
    echo "완료: $OUT"
    echo "실행 예: llama-gpu -m \"$OUT\" -st -p \"대한민국의 수도는?\""
}

if [ -f "$OUT" ]; then
    local_size=$(wc -c < "$OUT" | tr -d '[:space:]')
    if [ -f "$COMPLETE" ]; then
        mapfile -t completion < "$COMPLETE"
        if [ "${#completion[@]}" -eq 3 ] && [ "${completion[0]}" = "$URL" ] && \
            [[ "${completion[2]}" =~ ^[[:xdigit:]]{64}$ ]]; then
            # 검증된 모델은 네트워크 없이 재사용하며 같은 크기의 사후 변경도 탐지한다.
            if [ "${completion[1]}" != "$local_size" ] || [ "$local_size" -eq 0 ] || \
                [ "$(file_sha256 "$OUT")" != "${completion[2],,}" ]; then
                echo "완료 기록과 모델이 일치하지 않습니다 (파일 유지): $OUT" >&2
                exit 1
            fi
            echo "이미 있음: $OUT"
            show_complete
            exit 0
        fi
        # 이전의 URL+크기 2줄 기록은 해시 검증 전 legacy 파일로 취급한다.
    fi
fi

# HuggingFace LFS의 X-Linked-Etag는 원본 전체 SHA256이다. 최초 redirect의
# X-Linked-Size를 우선해 CDN이 Content-Length를 생략해도 검증할 수 있게 한다.
headers=$(curl -fsIL "$URL") || {
    echo "모델 검증 정보를 가져올 수 없습니다 (파일 유지): $OUT" >&2
    exit 1
}
metadata=$(printf '%s\n' "$headers" | awk '
    /^HTTP\// { size = "" }
    tolower($1) == "content-length:" { size = $2; sub(/\r$/, "", size) }
    tolower($1) == "x-linked-size:" { linked_size = $2; sub(/\r$/, "", linked_size) }
    tolower($1) == "x-linked-etag:" { sha = $2; gsub(/["\r]/, "", sha) }
    END { print linked_size != "" ? linked_size : size; print sha }
')
mapfile -t remote <<< "$metadata"
remote_size=${remote[0]:-}
remote_sha=${remote[1]:-}
case "$remote_size" in
    ''|*[!0-9]*|0)
        echo "원격 모델 크기를 확인할 수 없습니다 (파일 유지): $OUT" >&2
        exit 1 ;;
esac
if ! [[ "$remote_sha" =~ ^[[:xdigit:]]{64}$ ]]; then
    echo "원격 모델 SHA256을 확인할 수 없습니다 (파일 유지): $OUT" >&2
    exit 1
fi
remote_sha=${remote_sha,,}

if [ -f "$OUT" ]; then
    if [ "$local_size" -eq "$remote_size" ]; then
        if [ "$(file_sha256 "$OUT")" != "$remote_sha" ]; then
            echo "기존 모델 SHA256이 원격 모델과 다릅니다 (파일 유지): $OUT" >&2
            exit 1
        fi
        write_complete "$local_size" "$remote_sha"
        echo "이미 있음: $OUT"
        show_complete
        exit 0
    elif [ "$local_size" -gt "$remote_size" ]; then
        echo "기존 모델이 원격 모델보다 큽니다 (파일 유지): $OUT" >&2
        exit 1
    elif [ ! -e "$PART" ]; then
        # 이어받기나 복사 중 실패하더라도 기존 OUT는 검증 성공 전까지 보존한다.
        cp "$OUT" "$PART" || {
            echo "이어받을 파일을 복사할 수 없습니다 (기존 파일 유지): $OUT" >&2
            exit 1
        }
    fi
fi

# 다운로드가 끝났지만 rename 전에 중단된 .part는 검증 후 바로 게시한다.
part_size=0
if [ -f "$PART" ]; then part_size=$(wc -c < "$PART" | tr -d '[:space:]'); fi
if [ "$part_size" -ne "$remote_size" ]; then
    echo "다운로드: $F"
    curl -fL -C - -o "$PART" "$URL" || {
        echo "다운로드 실패 (다음 실행 시 이어받음): $PART" >&2
        exit 1
    }
fi
if [ ! -f "$PART" ] || [ "$(wc -c < "$PART" | tr -d '[:space:]')" -ne "$remote_size" ] || \
    [ "$(file_sha256 "$PART")" != "$remote_sha" ]; then
    echo "모델 크기 또는 SHA256 불일치 (파일 유지): $PART" >&2
    exit 1
fi
mv "$PART" "$OUT"
write_complete "$remote_size" "$remote_sha"
show_complete
MEOF
        rm -f "$staged"
        return 1
    fi
    if ! chmod 755 "$staged" || ! mv -f "$staged" "$_LLAMA_MODEL_GET_BIN"; then
        rm -f "$staged"
        return 1
    fi
}

app_install_llama_cpp() {
    termux_pkg_install "${_PKGS_LLAMA_CPP[@]}" || return 1
    _llama_write_gpu_launcher || return 1
    _llama_write_model_get || return 1

    if ! app_is_installed_gpu_native 2>/dev/null; then
        echo "[llama.cpp] 힌트: GPU 추론을 쓰려면 '시스템 → GPU 가속'을 먼저 설치하세요."
    fi
    echo "[llama.cpp] CPU: llama-cli / llama-server, GPU: llama-gpu (네이티브 OpenCL)."
    echo "[llama.cpp] 모델: llama-model-get [0.5b|1.5b|3b|3.5-2b|3.5-4b|hammer] 로 GGUF 다운로드 (3.5-*=최신 Qwen3.5 Q4, hammer=툴콜용 Hammer2.1-3b Q4)."
}

app_remove_llama_cpp() {
    # 백엔드 패키지는 llama-cpp 에 의존하므로 함께 제거된다
    termux_pkg_remove llama-cpp || return 1
    rm -f "$_LLAMA_GPU_BIN" "$_LLAMA_MODEL_GET_BIN"
}

app_is_installed_llama_cpp() {
    termux_pkg_is_installed llama-cpp
}
