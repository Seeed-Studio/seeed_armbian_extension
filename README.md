# seeed_armbian_extension

Armbian 扩展软件包源码仓库（`deb_source` 分支）：为 Seeed 的 Rockchip 平台设备（rk356x / rk3576 / rk3588 等）提供内核驱动、相机 ISP、GPU、无线等 Debian 源码包。每个顶层目录是一个独立的 deb 源码包。

## 目录说明

### 相机 / ISP

| 目录 | 包名 | 功能 |
|---|---|---|
| `camera_engine_rkaiq/` | `camera-engine-rkaiq-<soc>` | Rockchip 相机 ISP 3A 引擎（rkaiq）源码包，支持 rk3576 / rk3588 / rk356x。含 `rkaiq_3A_server`、`rkaiq` 库等，核心 AE/AWB 算法为闭源预编译 `.a` |
| `camera_engine_rkaiq_linux6.12/` | `camera-engine-rkaiq-<soc>` | rkaiq 的 Linux 6.12 适配版本（含 irfpa_isp 红外 ISP、rkisp demo 等） |
| `rk_camera_engine_rkaiq/` | — | 相机 IQ 标定文件（JSON）：imx708 / imx415 / GC05A2 / OS04A10 等传感器的 IQ 参数，来自 ackPeng/rk_camera_engine_rkaiq |
| `prebuilt/` | — | 已在设备上验证过的 deb 快照（rk356x / rk3572 / rk3576 / rk3588 各版本），可直接 dpkg 安装 |

### 无线（WiFi / BT / HaLow）

#### 蓝牙

| 目录 | 包名 | 功能 |
|---|---|---|
| `FCS960K-aic-bluz/` | `fcs960k-aic-bluez` | BlueZ 蓝牙协议栈，带 AIC FCS960K 芯片补丁 |
| `wq9201s-wifi-bt-dkms/` | `wq9201s-wifi-bt-dkms` | WQ9201S WiFi+BT 组合芯片驱动（DKMS），含固件 |

#### Morse Micro HaLow (802.11ah)

| 目录 | 包名 | 功能 |
|---|---|---|
| `morse-fgh100m-dkms/` | `morse-fgh100m-dkms` | Morse Micro FG-H100M HaLow WiFi 驱动（DKMS） |
| `hostapd_morse_tools/` | `hostapd-morse-tools` | HaLow AP 模式 hostapd |
| `wpa_supplicant_morese_tools/` | `wpa-supplicant-morse-tools` | HaLow 客户端认证 wpa_supplicant |
| `morsectrl_tools/` | `morsectrl-tools` | Morse Micro WiFi 控制工具（依赖 libnl-3） |

### 有线网络 / PCIe

| 目录 | 包名 | 功能 |
|---|---|---|
| `maxio-phy-dkms/` | `maxio-phy-dkms` | Maxio MAE0621A 千兆以太网 PHY 驱动（DKMS） |
| `realtek-r8125-dkms/` | `realtek-r8125-dkms` | Realtek r8125 2.5G 以太网驱动（DKMS），支持 RSS/MSIX/PTP |
| `pcie-rkep-dkms/` | `pcie-rkep-dkms` | Rockchip PCIe Endpoint 驱动，用于 RKNN NPU 卡（DKMS） |

### GPU / USB 外设

| 目录 | 包名 | 功能 |
|---|---|---|
| `rk3588_gmali/` | `libmali-bifrost-g31-g13p0-*` | Rockchip libmali GPU 用户态二进制驱动（GBM / EGL / GLES 变体） |
| `rk35xx_usb_gadget/` | `usbdevice-gadget-rk3588` | USB gadget 配置工具（`usbdevice`）+ systemd 服务，`./build-usbdevice-deb.sh` 构建 |

## 构建

各目录均为标准 Debian 源码包，在对应目录下：

```bash
dpkg-buildpackage -us -uc -b
```

DKMS 包安装后会在内核更新时自动重编译；相机 IQ 文件随 `camera-engine-rkaiq-<soc>` 包安装。

## 分支说明

- `deb_source`：纯源码分支，push 不触发 CI workflow（需从 `main` dispatch）
