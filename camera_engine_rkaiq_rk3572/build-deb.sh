#!/bin/bash
#
# build-deb.sh — Cross-compile the rk3572 camera-engine-rkaiq deb (ISP V351s)
# from this dedicated v6.0x33 tree, with the Rockchip SDK toolchain
# (Arm GNU 10.3-2021.07, MinSizeRel).
#
# The tree is a trimmed copy of the linux6.12-sdk
# external/camera_engine_rkaiq checkout (board-validated there as
# camera-engine-rkaiq-rk3572 6.0x33.0-1). ABI note: the closed-source 3A algo
# .a files are built with aarch64-rockchip1240 (GCC 12.4); linking them with
# Arm GNU 10.3 is fine under the standard AArch64 PCS — verified on board.
#
# Trimmed relative to the SDK tree: non-351s iqfiles, rkisp_demo, irfpa_isp,
# media_enquiry, rkisp_parser_demo, gen_mesh android prebuilts, aiisp_relate
# RKNN models, closed-source .a for other SoCs (and 32-bit arm variants),
# IspFec doc/sample. Top-level CMakeLists updated accordingly.
#
# Usage: ./build-deb.sh
#
# Environment:
#   DEB_RELEASE   — debian revision suffix (default: 1)
#   TOOLCHAIN_DIR — use an existing gcc-arm-10.3-2021.07 tree instead of
#                   downloading (must contain bin/<triple>-gcc)
#   TOOLCHAIN_URL — override toolchain tarball URL
#   TOOLCHAIN_CACHE — download/cache dir (default: ~/.cache/seeed-rkaiq-toolchain)

set -euo pipefail

SOC="rk3572"
IQDIR="isp351s/common"          # rk3572 IQ jsons live in the common/ subdir
ISPVER="-DISP_HW_V351s"
MINKVER="6.12.0"
EXTRA_DEPENDS=""

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

TOOLCHAIN_VERSION="10.3-2021.07"
TRIPLE="aarch64-none-linux-gnu"
TOOLCHAIN_TARBALL="gcc-arm-${TOOLCHAIN_VERSION}-x86_64-${TRIPLE}.tar.xz"
TOOLCHAIN_URL="${TOOLCHAIN_URL:-https://developer.arm.com/-/media/Files/downloads/gnu-a/${TOOLCHAIN_VERSION}/binrel/${TOOLCHAIN_TARBALL}}"
TOOLCHAIN_SHA256="1e33d53dea59c8de823bbdfe0798280bdcd138636c7060da9d77a97ded095a84"
TOOLCHAIN_CACHE="${TOOLCHAIN_CACHE:-${HOME}/.cache/seeed-rkaiq-toolchain}"

# Debian bullseye arm64, glibc-era compatible with the toolchain sysroot
LIBDRM_VERSION="2.4.104-1"
LIBDRM_BASE_URL="https://deb.debian.org/debian/pool/main/libd/libdrm"
LIBDRM2_SHA256="1dc606aa361307a8c5277c2a5ddedea40a4125874e887c98e82b33dacaa853b0"
LIBDRM_DEV_SHA256="dbbbc3d05b470d6d35b5f2daed4be893e41b74f9c7e58bf5be3d18849b14f78a"

# Host gcc builds the j2s/iq_check parser tools; m4 feeds iq_parser_v2's header generation (ninja step 'Generating
# RkAiqCalibDbTypesV2_M4.h'); without it the build dies mid-ninja.
for tool in cmake ninja m4 gcc xxd xz curl sha256sum dpkg-deb; do
    command -v "${tool}" >/dev/null 2>&1 || { echo "ERROR: missing tool: ${tool}"; exit 1; }
done

# --- toolchain acquisition -------------------------------------------------
if [ -n "${TOOLCHAIN_DIR:-}" ]; then
    [ -x "${TOOLCHAIN_DIR}/bin/${TRIPLE}-gcc" ] || { echo "ERROR: TOOLCHAIN_DIR does not contain bin/${TRIPLE}-gcc"; exit 1; }
    HOST_DIR="${TOOLCHAIN_DIR}"
else
    HOST_DIR="${TOOLCHAIN_CACHE}/gcc-arm-${TOOLCHAIN_VERSION}-x86_64-${TRIPLE}"
    if [ ! -x "${HOST_DIR}/bin/${TRIPLE}-gcc" ]; then
        mkdir -p "${TOOLCHAIN_CACHE}"
        TARBALL="${TOOLCHAIN_CACHE}/${TOOLCHAIN_TARBALL}"
        if [ ! -f "${TARBALL}" ] || ! echo "${TOOLCHAIN_SHA256}  ${TARBALL}" | sha256sum -c --status; then
            echo "=== Downloading ${TOOLCHAIN_TARBALL} ==="
            curl -fL --retry 3 -o "${TARBALL}" "${TOOLCHAIN_URL}"
        fi
        echo "${TOOLCHAIN_SHA256}  ${TARBALL}" | sha256sum -c -
        echo "=== Extracting toolchain ==="
        tar -xJf "${TARBALL}" -C "${TOOLCHAIN_CACHE}"
    fi
fi
SYSROOT="${HOST_DIR}/${TRIPLE}/libc"

# --- inject aarch64 libdrm into the toolchain sysroot ----------------------
# The toolchain file sets FIND_ROOT_PATH_MODE_* = ONLY, so libdrm must live
# inside the sysroot. Debian's multiarch lib path is invisible to
# find_library's default suffixes, hence the extra symlink in usr/lib.
STAMP="${SYSROOT}/.seeed-libdrm-${LIBDRM_VERSION}"
if [ ! -f "${STAMP}" ]; then
    echo "=== Injecting libdrm ${LIBDRM_VERSION} into sysroot ==="
    for pkg in libdrm2 libdrm-dev; do
        DEB="${TOOLCHAIN_CACHE}/${pkg}_${LIBDRM_VERSION}_arm64.deb"
        [ -f "${DEB}" ] || curl -fL --retry 3 -o "${DEB}" "${LIBDRM_BASE_URL}/${pkg}_${LIBDRM_VERSION}_arm64.deb"
    done
    echo "${LIBDRM2_SHA256}  ${TOOLCHAIN_CACHE}/libdrm2_${LIBDRM_VERSION}_arm64.deb" | sha256sum -c -
    echo "${LIBDRM_DEV_SHA256}  ${TOOLCHAIN_CACHE}/libdrm-dev_${LIBDRM_VERSION}_arm64.deb" | sha256sum -c -
    dpkg-deb -x "${TOOLCHAIN_CACHE}/libdrm2_${LIBDRM_VERSION}_arm64.deb" "${SYSROOT}"
    dpkg-deb -x "${TOOLCHAIN_CACHE}/libdrm-dev_${LIBDRM_VERSION}_arm64.deb" "${SYSROOT}"
    touch "${STAMP}"
fi
# Debian's multiarch lib dir is invisible to both find_library's default
# suffixes and the linker's transitive NEEDED resolution — expose the soname
# and the dev symlink in usr/lib (idempotent)
ln -sf aarch64-linux-gnu/libdrm.so "${SYSROOT}/usr/lib/libdrm.so"
ln -sf aarch64-linux-gnu/libdrm.so.2 "${SYSROOT}/usr/lib/libdrm.so.2"

# --- cross compile (mirrors rkaiq/build/linux/make-Makefiles-aarch64.bash) --
export AIQ_BUILD_HOST_DIR="${HOST_DIR}"
export AIQ_BUILD_TOOLCHAIN_TRIPLE="${TRIPLE}"
export AIQ_BUILD_SYSROOT=libc
export AIQ_BUILD_ARCH=aarch64
export PKG_CONFIG_LIBDIR="${SYSROOT}/usr/lib/aarch64-linux-gnu/pkgconfig:${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig"

VERSION=$(grep 'RK_AIQ_VERSION_REAL_V' "${SCRIPT_DIR}/rkaiq/RkAiqVersion.h" | head -1 | sed 's/.*"\(.*\)".*/\1/' | tr -d 'v')
DEB_RELEASE="${DEB_RELEASE:-1}"
PKG="camera-engine-rkaiq-${SOC}"
BUILD_DIR="${SCRIPT_DIR}/build/${SOC}"

echo "=== Building ${PKG} ${VERSION}-${DEB_RELEASE} (cross, MinSizeRel) ==="
rm -rf "${BUILD_DIR}"
cmake -G Ninja -S "${SCRIPT_DIR}" -B "${BUILD_DIR}" \
    -DCMAKE_TOOLCHAIN_FILE="${SCRIPT_DIR}/rkaiq/cmake/toolchains/gcc.cmake" \
    -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DRKAIQ_TARGET_SOC="${SOC}" \
    -DISP_HW_VERSION="${ISPVER}" \
    -DARCH=aarch64 \
    -DRKAIQ_BUILD_BINARY_IQ=OFF \
    -DRKAIQ_USE_RAWSTREAM_LIB=OFF \
    -DRKAIQ_HAVE_FAKECAM=ON \
    -DRKAIQ_ENABLE_AF=ON \
    -DRKAIQ_ENABLE_LIBDRM=ON \
    -DRKAIQ_HAVE_MULTIISP=ON \
    -DCMAKE_SKIP_RPATH=TRUE

if ! grep -qE '^LIBDRM_LIBRARY:FILEPATH=.*libdrm\.so$' "${BUILD_DIR}/CMakeCache.txt"; then
    echo "ERROR: libdrm not found inside cross sysroot — refusing to build without it"
    exit 1
fi

ninja -C "${BUILD_DIR}"

# --- stage and package ------------------------------------------------------
STAGING="${BUILD_DIR}/staging/${PKG}"
rm -rf "${STAGING}"
DESTDIR="${STAGING}" ninja -C "${BUILD_DIR}" install

# headers are intentionally not shipped yet (prebuilt ships 600 of them)
rm -rf "${STAGING}/usr/include"

# drop the SysV init script installed by cmake — the deb ships a native
# systemd unit only (sysv compat triggers deprecation warnings on systemd
# >= 255 and duplicate auto-start paths via systemd-sysv-generator)
rm -f "${STAGING}/etc/init.d/S40rkaiq_3A" \
      "${STAGING}/usr/etc/init.d/S40rkaiq_3A" \
      "${STAGING}/usr/etc/init.d/rkaiq_3A.sh"
rmdir -p "${STAGING}/usr/etc/init.d" 2>/dev/null || true
rmdir -p "${STAGING}/etc/init.d" 2>/dev/null || true

# --- SDK-tree staging layout fixups ------------------------------------------
# This tree keeps the upstream (unpatched) install rules: rkaiq_3A_server and
# the fec_calib ini files land under a doubled usr/usr/ prefix. Relocate them
# to where the systemd unit and the ISP expect them.
if [ -e "${STAGING}/usr/usr/bin/rkaiq_3A_server" ]; then
    mkdir -p "${STAGING}/usr/bin"
    mv "${STAGING}/usr/usr/bin/rkaiq_3A_server" "${STAGING}/usr/bin/"
fi
if [ -d "${STAGING}/usr/usr/share/fec_calib" ]; then
    mkdir -p "${STAGING}/usr/share"
    mv "${STAGING}/usr/usr/share/fec_calib" "${STAGING}/usr/share/"
fi
rm -rf "${STAGING}/usr/usr"

mkdir -p "${STAGING}/etc/iqfiles" "${STAGING}/lib/systemd/system" "${STAGING}/DEBIAN"
cp "${SCRIPT_DIR}"/rkaiq/iqfiles/"${IQDIR}"/*.json "${STAGING}/etc/iqfiles/"
cp "${SCRIPT_DIR}/debian/rkaiq_3A.service" "${STAGING}/lib/systemd/system/"

sed -e "s/@SOC@/${SOC}/g" \
    -e "s/@VERSION@/${VERSION}/g" \
    -e "s/@DEB_RELEASE@/${DEB_RELEASE}/g" \
    -e "s/@EXTRA_DEPENDS@/${EXTRA_DEPENDS}/g" \
    "${SCRIPT_DIR}/debian/control.in" > "${STAGING}/DEBIAN/control"
sed -e "s/@SOC@/${SOC}/g" \
    -e "s/@MINKVER@/${MINKVER}/g" \
    "${SCRIPT_DIR}/debian/camera-engine-rkaiq-@SOC@.postinst.in" > "${STAGING}/DEBIAN/postinst"
sed -e "s/@SOC@/${SOC}/g" \
    "${SCRIPT_DIR}/debian/camera-engine-rkaiq-@SOC@.prerm.in" > "${STAGING}/DEBIAN/prerm"
chmod 755 "${STAGING}/DEBIAN/postinst" "${STAGING}/DEBIAN/prerm"

OUT_DEB="${SCRIPT_DIR}/../${PKG}_${VERSION}-${DEB_RELEASE}_arm64.deb"
dpkg-deb --root-owner-group --build "${STAGING}" "${OUT_DEB}"

echo ""
echo "=== Done ==="
ls -lh "${OUT_DEB}"
