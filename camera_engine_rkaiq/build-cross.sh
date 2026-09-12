#!/bin/bash
#
# build-cross.sh — 用 Arm GCC 8.3 交叉工具链构建 camera-engine-rkaiq deb
#
# 背景: rkaiq 的 3A 算法核心是闭源 .a（Rockchip 用 Arm GCC 8.3-2019.03 编译），
#       用更新版本的 GCC（如 bookworm 的 GCC 12）编译开源部分再与之混链，
#       产物能编译运行但 AE 算法行为损坏（收敛到过曝）。必须用同代工具链。
#       详见经验记录与 prebuilt/ 目录的历史。
#
# 用法: bash build-cross.sh <rk3576|rk3588>
#
# 环境变量:
#   CROSS_HOME    工具链与 sysroot 的存放目录（默认 <脚本目录>/.cross）
#   GCC83_URL     工具链 tar.xz 的下载地址（默认按顺序尝试多个镜像）
#   DEB_RELEASE   deb 修订号（默认 1）
#   EXTRA_CMAKE   附加 cmake 参数（如试验优化级别）
#
# 前提: x86_64 Linux（交叉工具链宿主）。若以 root 运行会自动安装构建依赖。

set -euo pipefail

SOC="${1:?用法: $0 <rk3576|rk3588>}"
case "${SOC}" in
    rk3576) IQDIR=isp39 ;;
    rk3588) IQDIR=isp3x ;;
    *) echo "ERROR: 不支持的 SoC: ${SOC}"; exit 1 ;;
esac

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
CROSS_HOME="${CROSS_HOME:-${SRC_DIR}/.cross}"
TOOLCHAIN_DIR="${CROSS_HOME}/gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu"
SYSROOT_DIR="${CROSS_HOME}/sysroot"
BUILD_DIR="${SRC_DIR}/build-cross-${SOC}"
DEB_RELEASE="${DEB_RELEASE:-1}"

# ── 工具链与 sysroot 的固定版本（勿随意升级: 闭源 .a 要求同代编译器）──────
GCC_TARBALL="gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu.tar.xz"
GCC_SHA256="8ce3e7688a47d8cd2d8e8323f147104ae1c8139520eca50ccf8a7fa933002731"
GCC_URLS=(
    "https://github.com/armbian/mirror/releases/download/_toolchain/${GCC_TARBALL}"
    "https://mirrors.cstcloud.cn/armbian-releases/_toolchain/${GCC_TARBALL}"
    "https://storage.googleapis.com/mirror.tensorflow.org/developer.arm.com/-/media/Files/downloads/gnu-a/8.3-2019-03/binrel/${GCC_TARBALL}"
)
# buster 版 libdrm（glibc 2.28 基线，与 GCC 8.3 自带 sysroot 同代；
# bookworm 的 libdrm 引用 GLIBC_2.33 符号，链接会失败）
LIBDRM_DEV="libdrm-dev_2.4.97-1_arm64.deb"
LIBDRM_LIB="libdrm2_2.4.97-1_arm64.deb"
LIBDRM_URL_BASE="http://archive.debian.org/debian/pool/main/libd/libdrm"
LIBDRM_DEV_SHA256="21bd19c7e4ad86898e3613f45683630f5f42cd696b978ebced0b93a1d943104a"
LIBDRM_LIB_SHA256="c1521eb6b63dc794e9487e6fd6956201b97fc230d514ccf5bf767111e0f86efb"

fetch() { # fetch <url> <输出文件>
    local url=$1 out=$2
    command -v curl > /dev/null && { curl -fsSL --retry 3 -o "${out}" "${url}"; return; }
    wget -q -O "${out}" "${url}"
}

verify() { # verify <文件> <sha256>
    echo "$2  $1" | sha256sum -c --quiet
}

# ── 0. 构建依赖 ──────────────────────────────────────────
if [[ "$(id -u)" == 0 ]]; then
    apt-get update -qq || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
        gcc g++ cmake make m4 xxd dpkg-dev curl ca-certificates > /dev/null
fi
for t in gcc g++ cmake make m4 xxd dpkg-deb; do
    command -v "${t}" > /dev/null || { echo "ERROR: 缺少 ${t}，请先安装"; exit 1; }
done
[[ "$(uname -m)" == "x86_64" ]] || { echo "ERROR: 交叉工具链仅支持 x86_64 宿主"; exit 1; }

# ── 1. 工具链（已存在则跳过，支持 CI/本地缓存）─────────────
mkdir -p "${CROSS_HOME}"
if [[ ! -x "${TOOLCHAIN_DIR}/bin/aarch64-linux-gnu-gcc" ]]; then
    echo "=== 获取 Arm GCC 8.3-2019.03 交叉工具链 ==="
    TARBALL="${CROSS_HOME}/${GCC_TARBALL}"
    ok=0
    for url in "${GCC_URLS[@]}"; do
        echo "尝试: ${url}"
        if fetch "${url}" "${TARBALL}" && verify "${TARBALL}" "${GCC_SHA256}"; then
            ok=1; break
        fi
        echo "  失败，换下一个源"
    done
    [[ ${ok} == 1 ]] || { echo "ERROR: 工具链下载失败（可用 GCC83_URL 环境变量指定源）"; exit 1; }
    tar -xf "${TARBALL}" -C "${CROSS_HOME}"
    rm -f "${TARBALL}"
fi
echo "工具链: ${TOOLCHAIN_DIR}"
"${TOOLCHAIN_DIR}/bin/aarch64-linux-gnu-gcc" --version | head -1

# ── 2. libdrm sysroot（buster 2.4.97）─────────────────────
if [[ ! -f "${SYSROOT_DIR}/.ready" ]]; then
    echo "=== 准备 libdrm sysroot (buster 2.4.97) ==="
    rm -rf "${SYSROOT_DIR}"; mkdir -p "${SYSROOT_DIR}"
    for f in "${LIBDRM_DEV}:${LIBDRM_DEV_SHA256}" "${LIBDRM_LIB}:${LIBDRM_LIB_SHA256}"; do
        fname="${f%%:*}"; sha="${f##*:}"
        fetch "${LIBDRM_URL_BASE}/${fname}" "${CROSS_HOME}/${fname}"
        verify "${CROSS_HOME}/${fname}" "${sha}"
        dpkg-deb -x "${CROSS_HOME}/${fname}" "${SYSROOT_DIR}"
        rm -f "${CROSS_HOME}/${fname}"
    done
    # 源码用 #include <drm/xxx.h>，需要 drm -> libdrm 软链
    ln -sfn libdrm "${SYSROOT_DIR}/usr/include/drm"
    touch "${SYSROOT_DIR}/.ready"
fi

# ── 3. cmake 工具链文件 ──────────────────────────────────
TOOLCHAIN_CMAKE="${CROSS_HOME}/cross-toolchain.cmake"
cat > "${TOOLCHAIN_CMAKE}" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER   ${TOOLCHAIN_DIR}/bin/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_DIR}/bin/aarch64-linux-gnu-g++)
list(APPEND CMAKE_FIND_ROOT_PATH ${SYSROOT_DIR} ${TOOLCHAIN_DIR}/aarch64-linux-gnu)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
# exe 链接时让 ld 能找到 librkaiq.so 的 NEEDED 依赖与 -ldrm 短名
set(SYSROOT_LIBDIR ${SYSROOT_DIR}/usr/lib/aarch64-linux-gnu)
set(CMAKE_EXE_LINKER_FLAGS "-Wl,-rpath-link,\${SYSROOT_LIBDIR} -L\${SYSROOT_LIBDIR}")
set(CMAKE_SHARED_LINKER_FLAGS "-L\${SYSROOT_LIBDIR}")
EOF

# ── 4. 交叉编译（与 debian/rules.in 相同的参数）────────────
VERSION=$(grep 'RK_AIQ_VERSION_REAL_V' rkaiq/RkAiqVersion.h | head -1 | sed 's/.*"\(.*\)".*/\1/' | tr -d 'v')
echo "=== 交叉编译 camera-engine-rkaiq-${SOC} v${VERSION} ==="

# rk3576 的 C 实现路径使用 mmap64()，需 _LARGEFILE64_SOURCE 才有声明
# （仅限 rk3576；rk3588 加此宏会在板上触发 3A 服务 SIGSEGV，勿动）
EXTRA_C_FLAGS=""
[[ "${SOC}" == "rk3576" ]] && EXTRA_C_FLAGS="-DCMAKE_C_FLAGS=-D_LARGEFILE64_SOURCE"

cmake -B "${BUILD_DIR}" \
    -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_CMAKE}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DRKAIQ_TARGET_SOC="${SOC}" \
    -DRKAIQ_ENABLE_LIBDRM=ON \
    -DRKAIQ_ENABLE_AF=ON \
    -DRKAIQ_HAVE_MULTIISP=ON \
    -DLIBDRM_LIBRARY="${SYSROOT_DIR}/usr/lib/aarch64-linux-gnu/libdrm.so" \
    ${EXTRA_C_FLAGS} ${EXTRA_CMAKE:-}
cmake --build "${BUILD_DIR}" -j "$(nproc)"

# ── 5. 打包 deb ──────────────────────────────────────────
echo "=== 打包 ==="
STAGE="${BUILD_DIR}/stage/camera-engine-rkaiq-${SOC}"
rm -rf "${STAGE}"; mkdir -p "${STAGE}"
make -C "${BUILD_DIR}" DESTDIR="${STAGE}" install > /dev/null

install -d -m 0755 "${STAGE}/etc/iqfiles"
cp -a "rkaiq/iqfiles/${IQDIR}/"*.json "${STAGE}/etc/iqfiles/"

install -d -m 0755 "${STAGE}/lib/systemd/system"
install -m 0644 debian/rkaiq_3A.service "${STAGE}/lib/systemd/system/"

mkdir -p "${STAGE}/DEBIAN"
sed -e "s|@SOC@|${SOC}|g" -e "s|@VERSION@|${VERSION}|g" \
    -e "s|@DEB_RELEASE@|${DEB_RELEASE}|g" \
    debian/camera-engine-rkaiq-@SOC@.postinst.in > "${STAGE}/DEBIAN/postinst"
sed -e "s|@SOC@|${SOC}|g" -e "s|@VERSION@|${VERSION}|g" \
    -e "s|@DEB_RELEASE@|${DEB_RELEASE}|g" \
    debian/camera-engine-rkaiq-@SOC@.prerm.in > "${STAGE}/DEBIAN/prerm"
chmod 0755 "${STAGE}/DEBIAN/postinst" "${STAGE}/DEBIAN/prerm"
cat > "${STAGE}/DEBIAN/control" <<EOF
Package: camera-engine-rkaiq-${SOC}
Version: ${VERSION}-${DEB_RELEASE}
Architecture: arm64
Maintainer: Seeed Studio <zuobaozhu@gmail.com>
Depends: libc6 (>= 2.28), libdrm2 (>= 2.4.38), libgcc-s1 (>= 4.0), libstdc++6 (>= 8), systemd
Section: libs
Priority: optional
Description: Rockchip RKAIQ camera engine for ${SOC}
 Rockchip ISP and AIQ runtime libraries, binaries, and camera
 tuning profiles for the ${SOC} SoC. Built with the Arm GCC
 8.3-2019.03 toolchain (required by closed-source 3A algorithm
 libraries).
EOF

DEB="${SRC_DIR}/camera-engine-rkaiq-${SOC}_${VERSION}-${DEB_RELEASE}_arm64.deb"
dpkg-deb -b --root-owner-group "${STAGE}" "${DEB}"

echo "=== 完成 ==="
ls -lh "${DEB}"
echo "指纹: $(${TOOLCHAIN_DIR}/bin/aarch64-linux-gnu-readelf -p .comment "${STAGE}/usr/lib/librkaiq.so" 2>/dev/null | grep -m1 -oE '8\.3\.0' || echo '?')"
