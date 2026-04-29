#!/bin/bash
#
# publish-aptly.sh — 使用 aptly 构建 apt 仓库并发布到 GitHub Pages
#
# 用法: ./scripts/publish-aptly.sh <deb-directory>
#
# 环境变量:
#   APT_GPG_KEY_ID — GPG 签名密钥 ID
#

set -euo pipefail

DEB_DIR="${1:?Usage: $0 <deb-directory>}"
GPG_KEY="${APT_GPG_KEY_ID:?APT_GPG_KEY_ID not set}"
REPO_NAME="seeed-recomputer"
DISTRIBUTION="stable"
PUBLIC_DIR="$(pwd)/public"

echo "=== Step 1: Verify debs ==="
DEB_COUNT=$(find "${DEB_DIR}" -name '*.deb' | wc -l)
echo "Found ${DEB_COUNT} deb packages"
if [[ "${DEB_COUNT}" -eq 0 ]]; then
    echo "ERROR: No .deb files found in ${DEB_DIR}"
    exit 1
fi
find "${DEB_DIR}" -name '*.deb' -exec basename {} \;

echo ""
echo "=== Step 2: Configure aptly ==="
APTLY_ROOT="/tmp/aptly-work"
mkdir -p "${APTLY_ROOT}"

cat > "${APTLY_ROOT}/aptly.conf" << EOF
{
  "rootDir": "${APTLY_ROOT}/repo",
  "downloadConcurrency": 4,
  "downloadSpeedLimit": 0,
  "architectures": ["arm64"],
  "dependencyFollowSuggests": false,
  "dependencyFollowRecommends": false,
  "dependencyFollowAllVariants": false,
  "dependencyFollowSource": false,
  "gpgDisableSign": false,
  "gpgDisableVerify": true,
  "gpgProvider": "gpg2",
  "skipContents": false,
  "skipBz2": false,
  "ppaDistributorID": "ubuntu",
  "ppaCodename": ""
}
EOF

export APTLY_CONFIG="${APTLY_ROOT}/aptly.conf"

echo ""
echo "=== Step 3: Create or load aptly repository ==="
REPO_DIR="${APTLY_ROOT}/repo"
mkdir -p "${REPO_DIR}"

# 检查是否已有发布的仓库（从 GitHub Pages 缓存恢复）
# 每次都从零开始构建，确保一致性
aptly -config="${APTLY_CONFIG}" \
    repo create \
    -distribution="${DISTRIBUTION}" \
    -component="main" \
    -architectures="arm64" \
    "${REPO_NAME}" 2>/dev/null || true

echo ""
echo "=== Step 4: Add packages to repository ==="
for deb in "${DEB_DIR}"/*.deb; do
    echo "  Adding: $(basename "${deb}")"
    aptly -config="${APTLY_CONFIG}" \
        repo add "${REPO_NAME}" "${deb}"
done

echo ""
echo "=== Step 5: Verify repository contents ==="
aptly -config="${APTLY_CONFIG}" repo show "${REPO_NAME}"

echo ""
echo "=== Step 6: Publish repository ==="
aptly -config="${APTLY_CONFIG}" \
    -batch \
    -gpg-key="${GPG_KEY}" \
    -passphrase="" \
    -skip-signing=false \
    publish repo \
    -distribution="${DISTRIBUTION}" \
    -component="main" \
    -architectures="arm64" \
    -label="Seeed Studio" \
    -origin="Seeed Studio" \
    -description="Seeed Studio reComputer packages" \
    "${REPO_NAME}"

echo ""
echo "=== Step 7: Copy published files to public/ ==="
# aptly publish 输出到 pool/ 和 dists/ 结构
PUBLISH_DIR="${APTLY_ROOT}/repo/public"
if [[ -d "${PUBLISH_DIR}" ]]; then
    mkdir -p "${PUBLIC_DIR}"
    cp -r "${PUBLISH_DIR}"/* "${PUBLIC_DIR}/"

    # 复制 GPG 公钥
    gpg --export --armor "${GPG_KEY}" > "${PUBLIC_DIR}/seeed-repo.gpg"

    echo "Published structure:"
    find "${PUBLIC_DIR}" -type f | sort
else
    echo "ERROR: Published directory not found at ${PUBLISH_DIR}"
    exit 1
fi

echo ""
echo "=== Step 8: Generate summary ==="
echo "APT Repository published successfully!"
echo "URL: https://seeed-studio.github.io/seeed_armbian_extension/"
echo ""
echo "To use this repository:"
echo "  curl -fsSL https://seeed-studio.github.io/seeed_armbian_extension/seeed-repo.gpg | sudo gpg --dearmor -o /usr/share/keyrings/seeed-repo.gpg"
echo '  echo "deb [signed-by=/usr/share/keyrings/seeed-repo.gpg] https://seeed-studio.github.io/seeed_armbian_extension/ stable main" | sudo tee /etc/apt/sources.list.d/seeed.list'
echo "  sudo apt-get update"
