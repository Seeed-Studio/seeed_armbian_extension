#!/bin/bash
#
# build-prebuilt-deb.sh — Package the prebuilt rkaiq binaries from the RK3572
# Linux SDK (rockchip_linux6.12_release_v1.0.0) as a deb.
#
# The SDK's rkaiq was compiled with the internal Rockchip toolchain
# (aarch64-rockchip1240-linux-gnu, ISP_HW_V351s) which is not publicly
# available. This script packages the prebuilt .so/.bin files until we
# can cross-compile from source with a compatible toolchain.
#
# Source SDK: rockchip_linux6.12_release_v1.0.0_20260620
#   librkaiq.so       ← SDK rootfs /usr/lib/librkaiq.so (v1.10, 2192488 bytes)
#   rkaiq_3A_server   ← SDK rootfs /usr/bin/rkaiq_3A_server (34168 bytes)
#   IQ files          ← SDK buildroot .../rkaiq/iqfiles/isp351s/common/sc850sl_*.json
#
# For future source compilation, the build parameters are:
#   ISP_HW_VERSION=-DISP_HW_V351s
#   RKAIQ_TARGET_SOC=rk3572
#   IQDIR=isp351s
#   Toolchain: aarch64-rockchip1240-linux-gnu (SDK internal, not public)
#
# Usage: ./build-prebuilt-deb.sh <path-to-sdk-rootfs.img>
#   (or set SDK_ROOTFS env var; the script will extract the files)

set -euo pipefail

SOC="rk3572"
VERSION="1.0-1"
DEB_NAME="camera-engine-rkaiq-${SOC}_${VERSION}_arm64.deb"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IQ_DIR="${SCRIPT_DIR}/../rk_camera_engine_rkaiq"
OUT_DIR="${SCRIPT_DIR}/../prebuilt"

SDK_ROOTFS="${1:-${SDK_ROOTFS:-}}"
STAGING=$(mktemp -d /tmp/rkaiq-${SOC}-deb.XXXXXX)

cleanup() { rm -rf "${STAGING}"; }
trap cleanup EXIT

# --- extract prebuilt files from SDK rootfs ---
extract_from_sdk() {
    local img="${1:?Usage: build-prebuilt-deb.sh <sdk-rootfs.img>}"
    echo "Extracting rkaiq binaries from ${img}..."

    docker run --rm --privileged \
        -v "$(dirname "${img}"):/sdk:ro" \
        -v "${STAGING}:/out" \
        ghcr.io/armbian/docker-armbian-build:armbian-debian-trixie-latest \
        bash -c "
            set -e
            mount -o loop,ro /sdk/$(basename "${img}") /mnt
            cp /mnt/usr/lib/librkaiq.so /out/
            cp /mnt/usr/bin/rkaiq_3A_server /out/
            cd / && umount /mnt
        "
}

if [[ -n "${SDK_ROOTFS}" ]] && [[ -f "${SDK_ROOTFS}" ]]; then
    extract_from_sdk "${SDK_ROOTFS}"
else
    # look for pre-staged files (for CI / offline builds)
    if [[ -f "${SCRIPT_DIR}/prebuilt/librkaiq.so" ]] && [[ -f "${SCRIPT_DIR}/prebuilt/rkaiq_3A_server" ]]; then
        echo "Using pre-staged binaries from ${SCRIPT_DIR}/prebuilt/"
        cp "${SCRIPT_DIR}/prebuilt/librkaiq.so" "${STAGING}/"
        cp "${SCRIPT_DIR}/prebuilt/rkaiq_3A_server" "${STAGING}/"
    else
        echo "ERROR: Provide SDK rootfs.img path or stage binaries in ${SCRIPT_DIR}/prebuilt/"
        echo "  export SDK_ROOTFS=/path/to/rootfs.img && $0"
        exit 1
    fi
fi

# --- assemble deb ---
mkdir -p "${STAGING}/deb/DEBIAN" \
         "${STAGING}/deb/usr/bin" \
         "${STAGING}/deb/usr/lib" \
         "${STAGING}/deb/lib/systemd/system" \
         "${STAGING}/deb/etc/iqfiles"

cp "${STAGING}/rkaiq_3A_server" "${STAGING}/deb/usr/bin/"
chmod 755 "${STAGING}/deb/usr/bin/rkaiq_3A_server"
cp "${STAGING}/librkaiq.so" "${STAGING}/deb/usr/lib/"

cp "${SCRIPT_DIR}/debian/rkaiq_3A.service" "${STAGING}/deb/lib/systemd/system/"

# IQ files (filtered for this SoC's sensor set)
for iq in "${IQ_DIR}"/sc850sl_*.json; do
    [[ -f "$iq" ]] && cp "$iq" "${STAGING}/deb/etc/iqfiles/"
done

cat > "${STAGING}/deb/DEBIAN/control" <<EOF
Package: camera-engine-rkaiq-${SOC}
Version: ${VERSION}
Architecture: arm64
Maintainer: Seeed Studio <support@seeed.com>
Depends: systemd
Description: Rockchip camera engine rkaiq 3A server for ${SOC} (ISP V351s)
 Prebuilt from RK3572 Linux SDK (rockchip_linux6.12_release_v1.0.0).
 Contains librkaiq.so, rkaiq_3A_server and sc850sl IQ calibration files.
 Built with aarch64-rockchip1240-linux-gnu (SDK internal toolchain).
EOF

cat > "${STAGING}/deb/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload || true
        systemctl enable rkaiq_3A.service || true
    fi
fi
exit 0
EOF
chmod 755 "${STAGING}/deb/DEBIAN/postinst"

# --- build ---
mkdir -p "${OUT_DIR}"
dpkg-deb --build --root-owner-group "${STAGING}/deb" "${OUT_DIR}/${DEB_NAME}"
echo "=== Built: ${OUT_DIR}/${DEB_NAME} ($(du -h "${OUT_DIR}/${DEB_NAME}" | cut -f1))"
