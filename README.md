# OpenWrt-X96MaxPlus-N1

专为 **X96 Max+ (Amlogic S905X3)** 与 **斐讯 N1 (Amlogic S905D)** 打造的持续维护 OpenWrt 固件项目。

> 理念继承自已归档的 [haiibo/OpenWrt](https://github.com/haiibo/OpenWrt) ARMv8 Plus，
> 但**不复制旧代码** —— 全面基于当前上游重新构建：
> 现代 OpenWrt + 当前稳定 Linux Kernel + 当前 LuCI + 当前插件源码。

[![Build](https://github.com/zhb7670/OpenWrt-X96MaxPlus-N1-test/actions/workflows/build-from-source.yml/badge.svg)](https://github.com/zhb7670/OpenWrt-X96MaxPlus-N1-test/actions/workflows/build-from-source.yml)

---

## 一、支持的设备

本项目**只做这两个硬件系列**，其他 Amlogic 盒子一律不构建。

| 设备 | SoC | 说明 |
|---|---|---|
| **X96 Max+** | Amlogic S905X3 | 含各网卡/WiFi 变体 |
| **斐讯 N1** | Amlogic S905D | 标准版 / DMA-thresh 版 |

## 二、硬件矩阵（来自 OPHUB model database，非猜测）

### X96 Max+ / S905X3 全部变体

| ID | 型号 | DTB | 网卡 | WiFi | 官方BUILD |
|---|---|---|---|---|---|
| 501 | X96-Max+_100Mb | `meson-sm1-x96-max-plus-100m.dtb` | **1Gb** | rtl8822cs | ✅ |
| 502 | X96-Max+_1GB | `meson-sm1-x96-max-plus.dtb` | 1Gb | rtl8822cs | — |
| 503 | X96-Max+(OverClock) | `meson-sm1-x96-max-plus-oc.dtb` | 1Gb | rtl8822cs | — |
| 504 | X96-Max+(IP1001M) | `meson-sm1-x96-max-plus-ip1001m.dtb` | 1Gb(IP1001M) | brcm4354 | — |
| 505 | X96-Max+_A100 | `meson-sm1-x96-max-plus-a100.dtb` | 100Mb | AM7256 | — |
| 506 | X96-Max+_2101 | `meson-sm1-x96-max-plus-2101.dtb` | 1Gb(JL2xx1) | WiFi/BT | — |
| 507 | X96-Max+Q1 | `meson-sm1-x96-max-plus-q1.dtb` | 100Mb | WiFi | — |
| 508 | X96-Max+Q2 | `meson-sm1-x96-max-plus-q2.dtb` | 1Gb | qca9377 | — |
| 509 | X96-Air-1Gb | `meson-sm1-x96-air-gbit.dtb` | 1Gb | WiFi | — |
| 510 | X96-Air-100Mb | `meson-sm1-x96-air.dtb` | 100Mb | WiFi | — |

> ⚠️ **重要（实测修正）**：数据库里 `X96-Max+_100Mb` (ID 501) 虽标注 `1Gb-Nic`，
> 但其 DTB `meson-sm1-x96-max-plus-100m.dtb` **把 GMAC 限速在 100M**（本机只 advertise 10/100baseT）。
> 本机实测：PHY 为 **RTL8211F 千兆芯片**，对端已 advertise `1000baseT`，但仍被协商到 100Mb/s
> → **根因是 DTB 限速，不是硬件**。
>
> ✅ **修复**：改用 ID 502 对应的 BOARD 名 **`s905x3-x96max`**（DTB `meson-sm1-x96-max-plus.dtb`），
> 网口恢复千兆。已固化到两个工作流的默认值。

### N1 / S905D 全部变体

| ID | 型号 | DTB | 网卡 | WiFi | 官方BUILD |
|---|---|---|---|---|---|
| 101 | Phicomm-N1 | `meson-gxl-s905d-phicomm-n1.dtb` | 1Gb | brcm43455 | ✅ |
| 102 | Phicomm-N1(DMA-thresh) | `meson-gxl-s905d-phicomm-n1-thresh.dtb` | 1Gb | brcm43455 | — |

### 本机（开发者机器）确认

| 项 | 值 |
|---|---|
| 主板丝印 | X96 Q5X3 V4.1 |
| SoC | Amlogic S905X3 |
| RAM / eMMC | 4GB / 64GB |
| WiFi/蓝牙 模块 | Fn-Link **8274B-SR** = 芯片 **RTL8822CS** |
| 有线网口 PHY | **RTL8211F**（千兆，phy_id `0x001cc916`） |
| 标签 | QCPASS 4+64+W522A |
| **采用 BOARD 名** | **`s905x3-x96max`**（ID 502 千兆，DTB `meson-sm1-x96-max-plus.dtb`） |

> 原用 ID 501 (`s905x3`) 的 100m DTB 会导致有线只有 100M，已修正为千兆 BOARD。

## 三、构建路线（两条，用途不同）

本项目提供**两套独立工作流**，产物差异很大，按需选用：

| 工作流 | 源 | 插件量 | 产物大小 | 用途 |
|---|---|---|---|---|
| **`build-from-source.yml`** ⭐ | `coolsnowwolf/lede` master | **全量（600+ 包）** | ~680 MB | **主力固件**（全套插件） |
| `build.yml` | `openwrt` 官方源 | 精简（~60 包） | ~340 MB | 轻量测试 / 快速验证 |

> ⭐ **日常刷机用 `build-from-source.yml`**（lede 全量）。`build.yml`（ImageBuilder）仅用于快速验证编译链路。

### 主力构建（lede 全量）

| 项 | 值 |
|---|---|
| 源码 | `coolsnowwolf/lede` `master` |
| 配置目录 | `config/lede_master/` |
| 打包 | [zhb7670/amlogic-s9xxx-openwrt](https://github.com/zhb7670/amlogic-s9xxx-openwrt) fork |
| 内核 | `ophub/kernel` `stable` tag，auto_kernel 跟随最新（当前 6.18.y） |
| **Board** | **`s905x3-x96max`** (X96Max+ 千兆) + `s905d` (N1) |
| **rootfs 分区** | **3072 MiB (3G)** |
| 默认 IP | `192.168.1.1` |
| 默认账号 | `root` / `password` |
| 构建耗时 | ~4 小时（全量编译） |

### 本固件特性（在 lede 全量基础上的定制）

- **千兆有线网口**：`s905x3-x96max` BOARD（DTB `meson-sm1-x96-max-plus.dtb`），非 100m 限速版
- **rootfs 3G**：刷机后 `/` 分区 3072 MiB，可用约 2.9G
- **Docker**：
  - 界面：`luci-app-dockerman` + `luci-i18n-dockerman-zh-cn`（中文）
  - 已移除冲突的旧包 `luci-app-docker`
  - 完整运行时：`docker` + `dockerd` + `containerd` + `runc` + `docker-compose`
  - 预置 `/etc/docker/daemon.json`：DNS `223.5.5.5 / 119.29.29.29`，`data-root = /opt/docker`，日志轮转
  - 首启幂等创建 `/opt/docker`，**绝不执行分区/格式化**（无外接盘也能正常工作）

## 四、刷机方法

### 1. 下载
从 [Releases](../../releases) 下载对应设备的 `.img.gz` 文件。

| 设备 | 推荐文件 |
|---|---|
| **X96 Max+** | `openwrt_lede_amlogic_s905x3-x96max_k6.18.55_*.img.gz` |
| **斐讯 N1** | `openwrt_lede_amlogic_s905d_k6.18.55_*.img.gz` |

> 文件名里的 `s905x3-x96max` = **千兆网口版**（对应 ID 502 DTB）。
> `k6.18.55` 为新版内核，`k6.12.112` 更保守，二者择一即可。

### 2. 写入 SD 卡 / U 盘
用 **balenaEtcher** / **Rufus** / `dd` 把 `.img` 写入 SD 或 U 盘。
```bash
# Linux 示例（先解压 .gz，再确认 /dev/sdX 是你自己的卡！）
gunzip -c openwrt_lede_amlogic_s905x3-x96max_k6.18.55_*.img.gz | \
  sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

### 3. 启动
- **X96 Max+**：插入 SD 卡，按住复位键（AV 口内的按钮）通电，直到出现 OpenWrt 启动画面。
- **N1**：插入 U 盘/SD，通电即可（已刷过 OpenWrt 的 N1 直接从 U 盘启动）。

### 4. 写入 eMMC（可选，推荐）
1. 从 SD/U 盘启动后，浏览器打开 `http://192.168.1.1`（root / password）
2. `系统` → `Amlogic 服务` → `安装 OpenWrt` → 选择目标 eMMC
3. 安装完成后拔掉 SD 卡重启

## 五、恢复 / 救砖

| 情况 | 恢复方法 |
|---|---|
| 刷错固件，仍能进 U-Boot | 重新用 SD 卡启动原厂/正确固件 |
| X96 Max+ 变砖 | 用 **Amlogic USB Burning Tool** + 原厂线刷包（需拆机短接或复位键进 MaskROM） |
| N1 变砖 | 用 **USB Burning Tool** + N1 原厂降级包（需拆机短接触点） |
| 配置错误无法进 LuCI | 拔电后按住复位键通电，进入 **failsafe 模式**（`http://192.168.1.1`） |

> 强烈建议刷机前备份原厂固件与 MAC 地址。

## 六、刷机后验证

```sh
# ① 千兆有线网口（期望 1000Mb/s）
ethtool eth0 | grep Speed
cat /proc/device-tree/model          # 不应再出现 "100Mb/s"

# ② rootfs 3G（期望 ~3G 分区）
df -h /

# ③ Docker
docker info | grep "Docker Root Dir" # 期望 /opt/docker
docker version                        # 客户端+服务端均正常
ls /usr/lib/lua/luci/i18n/ | grep dockerman   # 中文语言包存在
```

## 七、路线图

| 阶段 | 内容 | 状态 |
|---|---|---|
| **Phase 1** | OpenWrt + Kernel + Amlogic + X96Max+ + N1 最小可启动 | ✅ 完成 |
| **Phase 2** | 千兆网口修正 + rootfs 3G + Docker 重构 | ✅ 完成 |
| Phase 2 | Samba / NFS / SQM / MWAN3 / WireGuard / OpenVPN / DDNS / UPnP / WOL | 🔄 |
| Phase 3 | SmartDNS / AdGuard Home / MosDNS / OpenClash / PassWall / PassWall2 / Xray / V2Ray | 🔄 |
| Phase 4 | qBittorrent / Transmission / Aria2 / Rclone / Netdata | ⏳ |

> 原则：**先保证编译成功 → 镜像生成 → DTB 正确 → 刷机启动，再逐步加入插件。**
> 若某插件无法编译，记录原因，不强行塞入导致整个矩阵失败。

## 八、自动构建

- **主力（全量）**：Actions → `Build OpenWrt from Source (X96Max+ / N1)` → Run workflow
- **轻量（精简）**：Actions → `Build OpenWrt (X96Max+ / N1)` → Run workflow
- 产物：`*.img.gz` + `sha256sum.txt`，上传 Artifact 并发布 Release
- 全量编译耗时约 4 小时

## 九、开发说明

```
.
├── .github/workflows/
│   ├── build-from-source.yml            # ⭐ 主力：lede 全量编译
│   └── build.yml                        # 轻量：官方源 ImageBuilder
├── config/
│   ├── lede_master/                     # ⭐ 主力配置（build-from-source 用）
│   │   ├── config                       # 完整 .config（600+ 包）
│   │   ├── diy-part1.sh                 # feeds update 前
│   │   ├── diy-part2.sh                 # feeds update 后
│   │   └── feeds.conf.default
│   └── imagebuilder/                    # 轻量配置（build.yml 用）
│       ├── imagebuilder.sh
│       ├── config
│       └── files/
├── files/                               # ⭐ 全量路线的自定义 overlay 注入
│   ├── etc/docker/daemon.json
│   └── etc/uci-defaults/99-docker-dataroot
└── README.md
```

**修改设备范围**：编辑工作流的 `openwrt_board`（默认 `s905x3-x96max_s905d`）。
**调整 rootfs 大小**：编辑工作流的 `openwrt_size`（默认 `3072` MiB）。
**新增插件（全量）**：加入 `config/lede_master/config`，格式 `CONFIG_PACKAGE_xxx=y`。
**新增插件（轻量）**：加入 `config/imagebuilder/config`，格式 `CONFIG_PACKAGE_xxx=y`。
**新增 overlay 文件（全量）**：放入仓库根 `files/`（workflow 自动 `mv files openwrt/files`）。

## 十、致谢

- [ophub/amlogic-s9xxx-openwrt](https://github.com/ophub/amlogic-s9xxx-openwrt) — Amlogic 打包体系
- [ophub/kernel](https://github.com/ophub/kernel) — 内核
- [unifreq/openwrt_packit](https://github.com/unifreq/openwrt_packit) — 原始打包脚本
- [haiibo/OpenWrt](https://github.com/haiibo/OpenWrt) — 项目理念来源
- OpenWrt / ImmortalWrt 上游

## 十一、许可

GPL-2.0
