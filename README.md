# Seeed reComputer APT Repository

APT 仓库分支，使用 [aptly](https://www.aptly.info/) 管理，通过 GitHub Pages 托管。

## 使用方法

```bash
# 添加 GPG key
curl -fsSL https://seeed-studio.github.io/seeed_armbian_extension/seeed-repo.gpg \
    | sudo gpg --dearmor -o /usr/share/keyrings/seeed-repo.gpg

# 添加源
echo "deb [signed-by=/usr/share/keyrings/seeed-repo.gpg] https://seeed-studio.github.io/seeed_armbian_extension/ stable main" \
    | sudo tee /etc/apt/sources.list.d/seeed.list

# 安装包
sudo apt-get update
sudo apt-get install <package-name>
```

## 包列表

| 包名 | 说明 |
|------|------|
| `fcs960k-aic-bluez` | FCS960K AIC 蓝牙定制 bluez |
| `usbdevice-gadget` | USB gadget 模式工具 |
| `hostapd-morse-tools` | Morse FGH100M hostapd 工具 |
| `morsectrl-tools` | Morse FGH100M 控制工具 |
| `wpa-supplicant-morse-tools` | Morse FGH100M wpa_supplicant 工具 |
| `camera-engine-rkaiq-rk3576` | RK3576 相机引擎 |
| `camera-engine-rkaiq-rk3588` | RK3588 相机引擎 |
| `libmali-g610` | Mali-G610 GPU 用户态驱动 |
| `realtek-r8125-kmod` | Realtek r8125 网卡 DKMS 驱动 |

## CI 工作流

### 自动构建

当 `deb_souceive` 分支有新提交时，GitHub Actions 自动：
1. 构建源码包（fcs960k、hostapd、morsectrl、wpa-supplicant、usbdevice）
2. 下载预编译包（camera-engine、libmali、r8125）从 GitHub Releases
3. 使用 aptly 生成 apt 仓库元数据
4. GPG 签名
5. 部署到 GitHub Pages

### 手动触发

在 Actions 页面手动运行 "Build and Publish APT Repository"，可指定源码分支。

## 新增 Secrets

在 GitHub 仓库 Settings > Secrets 中添加：

| Secret | 说明 |
|--------|------|
| `ARMBIAN_APT_GPG_PRIVATE_KEY` | GPG 私钥（base64 编码） |
| `ARMBIAN_APT_GPG_KEY_ID` | GPG 密钥 ID |

### 生成 GPG 密钥

```bash
# 生成密钥
gpg --full-generate-key

# 导出私钥（用于 GitHub Secret）
gpg --export-secret-keys <KEY_ID> | base64

# 导出公钥（用于仓库分发）
gpg --export --armor <KEY_ID>
```

## 仓库结构

```
.github/workflows/build-and-publish.yml   # CI 工作流
scripts/build-all-debs.sh                  # 本地构建脚本
scripts/publish-aptly.sh                   # aptly 发布脚本
```

发布的 apt 仓库结构（由 aptly 自动生成）：

```
public/
├── dists/
│   └── stable/
│       ├── main/
│       │   └── binary-arm64/
│       │       ├── Packages
│       │       └── Packages.gz
│       ├── Release
│       ├── Release.gpg
│       └── InRelease
├── pool/
│   └── main/
│       └── .../*.deb
└── seeed-repo.gpg
```
