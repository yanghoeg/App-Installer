#!/data/data/com.termux/files/usr/bin/bash
# Shared, pinned SASM source-build snippet for ARM64 proot adapters.
# Upstream release v3.16.0 is commit c622d5a0f00e1391171b372dac42af0f54dc2538.

sasm_build_source_script() {
    cat <<'EOF'
set -eu
sasm_version='3.16.0'
sasm_commit='c622d5a0f00e1391171b372dac42af0f54dc2538'

if [ -x /usr/bin/sasm ] && [ -d /usr/share/sasm ]; then
    exit 0
fi
sasm_src=$(mktemp -d "${TMPDIR:-/tmp}/sasm-${sasm_version}.XXXXXX")
trap 'rm -rf "$sasm_src"' EXIT
git clone --depth 1 --branch "v${sasm_version}" \
    https://github.com/Dman95/SASM.git "$sasm_src"
actual_commit=$(git -C "$sasm_src" rev-parse HEAD)
[ "$actual_commit" = "$sasm_commit" ] || {
    echo "[ERROR] SASM source revision mismatch: expected $sasm_commit, got $actual_commit" >&2
    exit 1
}
cd "$sasm_src"
qmake PREFIX=/usr SASM.pro
make --jobs "$(nproc)"
make install
test -x /usr/bin/sasm
test -d /usr/share/sasm
EOF
}
