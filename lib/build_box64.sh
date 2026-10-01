#!/data/data/com.termux/files/usr/bin/bash
# Shared, pinned Box64 source-build snippet for ARM64 proot adapters.
# Upstream release v0.4.4 is commit 2f130fab1d6e1a4ee8a71dc60cfdfcc839ad192a.

box64_build_source_script() {
    cat <<'EOF'
set -eu
box64_version='0.4.4'
box64_commit='2f130fab1d6e1a4ee8a71dc60cfdfcc839ad192a'
if command -v box64 >/dev/null 2>&1; then
    exit 0
fi
box64_src=$(mktemp -d "${TMPDIR:-/tmp}/box64-${box64_version}.XXXXXX")
trap 'rm -rf "$box64_src"' EXIT
git clone --depth 1 --branch "v${box64_version}" \
    https://github.com/ptitSeb/box64.git "$box64_src"
actual_commit=$(git -C "$box64_src" rev-parse HEAD)
[ "$actual_commit" = "$box64_commit" ] || {
    echo "[ERROR] Box64 source revision mismatch: expected $box64_commit, got $actual_commit" >&2
    exit 1
}
cmake -S "$box64_src" -B "$box64_src/build" \
    -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=Release
cmake --build "$box64_src/build" --parallel "$(nproc)"
cmake --install "$box64_src/build"
command -v box64 >/dev/null 2>&1
EOF
}
