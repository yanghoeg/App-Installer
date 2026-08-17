#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: code-server — Termux native (tur-repo)
# 브라우저에서 여는 VS Code. 서버형이라 .desktop 런처는 생성하지 않는다.
# (데스크탑용 VS Code는 별도 'vscode' 항목)

app_install_code_server() {
    termux_pkg_enable_repo tur-repo || return 1
    termux_pkg_install code-server || return 1
    echo "[code-server] 'code-server --bind-addr 127.0.0.1:8080' 후 브라우저로 접속하세요."
    echo "[code-server] 비밀번호: ~/.config/code-server/config.yaml"
}

app_remove_code_server() {
    termux_pkg_remove code-server
}

app_is_installed_code_server() {
    termux_pkg_is_installed code-server
}
