#!/bin/bash
#
# build-all-debs.sh — 从源码构建所有 deb 包
#
# 用法: ./scripts/build-all-debs.sh [output-dir]
#
# 前提: 在 deb_souceive 分支的源码目录中运行
#

set -euo pipefail

OUTPUT_DIR="${1:-$(pwd)/output/debs}"
mkdir -p "${OUTPUT_DIR}"

PACKAGES=(
    "FCS960K-aic-bluz"
    "hostapd_morse_tools"
    "morsectrl_tools"
    "wpa_supplicant_morese_tools"
    "rk35xx_usb_gadget"
)

echo "=== Building ${#PACKAGES[@]} packages ==="
echo "Output: ${OUTPUT_DIR}"
echo ""

FAILED=()

for pkg in "${PACKAGES[@]}"; do
    echo "--- Building: ${pkg} ---"
    if [[ ! -d "${pkg}" ]]; then
        echo "  WARNING: directory ${pkg} not found, skipping"
        continue
    fi

    pushd "${pkg}" > /dev/null

    if [[ -f "Makefile" ]] && grep -q "^deb:" Makefile; then
        # 有 make deb 目标
        make deb 2>&1 | tail -5
    elif [[ -f "debian/rules" ]]; then
        # 标准 debian 包
        dpkg-buildpackage -us -uc -b 2>&1 | tail -5
    else
        echo "  WARNING: no build system found for ${pkg}"
        FAILED+=("${pkg}")
        popd > /dev/null
        continue
    fi

    # 收集构建产物
    find . -name '*.deb' -exec cp {} "${OUTPUT_DIR}/" \;
    DEB_COUNT=$(find "${OUTPUT_DIR}" -name "${pkg}*.deb" -o -name "*${pkg}*.deb" 2>/dev/null | wc -l)
    echo "  Produced ${DEB_COUNT} deb file(s)"

    popd > /dev/null
    echo ""
done

echo "=== Build Summary ==="
echo "Output directory: ${OUTPUT_DIR}"
echo "Deb files:"
ls -lh "${OUTPUT_DIR}"/*.deb 2>/dev/null || echo "  (none)"

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    echo "WARNING: ${#FAILED[@]} package(s) failed: ${FAILED[*]}"
fi
