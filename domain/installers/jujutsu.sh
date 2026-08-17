#!/data/data/com.termux/files/usr/bin/bash
# DOMAIN: Jujutsu — Termux native (tur-repo)
# Git 호환 VCS + lazyjj TUI. CLI 전용이라 .desktop 런처는 생성하지 않는다.

_PKGS_JUJUTSU=(jujutsu lazyjj)

app_install_jujutsu() {
    termux_pkg_enable_repo tur-repo || return 1
    termux_pkg_install "${_PKGS_JUJUTSU[@]}" || return 1
    echo "[Jujutsu] jj / lazyjj 사용 가능. 기존 git 저장소에서 'jj git init --colocate'."
}

app_remove_jujutsu() {
    termux_pkg_remove "${_PKGS_JUJUTSU[@]}"
}

app_is_installed_jujutsu() {
    termux_pkg_is_installed jujutsu
}
