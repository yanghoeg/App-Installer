#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: PyTorch + ONNX Runtime — Termux native (termux-main)
# 온디바이스 ML 런타임. CLI/라이브러리 전용이라 .desktop 런처는 생성하지 않는다.
# 용량이 크다: python-torch 약 254MB + 의존성(openblas, numpy), onnxruntime 약 22MB.

_PKGS_ML_PYTHON=(python-torch onnxruntime)

app_install_ml_python() {
    echo "[ML] python-torch(약 254MB) + onnxruntime(약 22MB)을 설치합니다. 수 분 소요됩니다."
    termux_pkg_install "${_PKGS_ML_PYTHON[@]}" || return 1
    echo "[ML] python -c 'import torch; print(torch.__version__)' 로 확인하세요."
}

app_remove_ml_python() {
    termux_pkg_remove "${_PKGS_ML_PYTHON[@]}"
}

app_is_installed_ml_python() {
    termux_pkg_is_installed python-torch
}
