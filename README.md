# OpenWrt-X96MaxPlus-N1

专为 **X96 Max+ (Amlogic S905X3)** 与 **斐讯 N1 (Amlogic S905D)** 打造的持续维护 OpenWrt 固件项目。

> 理念继承自已归档的 [haiibo/OpenWrt](https://github.com/haiibo/OpenWrt) ARMv8 Plus，
> 但**不复制旧代码** —— 全面基于当前上游重新构建：
> 现代 OpenWrt + 当前稳定 Linux Kernel + 当前 LuCI + 当前插件源码。

[![Build](https://github.com/zhb7670/OpenWrt-X96MaxPlus-N1-test/actions/workflows/build-from-source.yml/badge.svg)](https://github.com/zhb7670/OpenWrt-X96MaxPlus-N1-test/actions/workflows/build-from-source.yml)

---

## ✅ 当前状态（2026-10-05）

| 项 | 值 |
|---|---|
| 最新构建 | run [`37343091946`](https://github.com/zhb7670/OpenWrt-X96MaxPlus-N1-test/actions/runs/37343091946) |
| 结果 | ✅ **success** |
| 耗时 | **5h 27m 49s**（冷编译，含 ccache 恢复失败） |
| Release | [`OpenWrt_X96MaxPlus_N1_lede_master_2026.10.05`](../../releases) |
| 下次构建预期 | **20-40 分钟**（ccache 基线已建立） |

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
| Board | **`s905x3-x96max`** (X96Max+ 千兆) + `s905d` (N1) |
| **rootfs 分区** | **3072 MiB (3G)** |
| 默认 IP | `192.168.1.1` |
| 默认账号 | `root` / `password` |
| 构建耗时 | **5h28m**（冷编译，2026-10-05 实测） |

### 本固件特性（在 lede 全量基础上的定制）

- **千兆有线网口**：`s905x3-x96max` BOARD（DTB `meson-sm1-x96-max-plus.dtb`），非 100m 限速版
- **rootfs 3G**：刷机后 `/` 分区 3072 MiB，可用约 2.9G
- **Docker**：见下节「四、Docker 说明」

## 四、Docker 说明（大白话版）

### 4.1 装了哪些包

| 包 | 干什么的 |
|---|---|
| `docker` | 命令行工具（你敲 `docker ps` 用的） |
| `dockerd` | 后台守护进程（真正干活的引擎） |
| `containerd` | 更底层的容器运行时（dockerd 依赖它） |
| `runc` | 真正创建/启动容器的执行器 |
| `docker-compose` | 用 yaml 文件一次起一堆容器 |
| `luci-app-dockerman` | LuCI 里的 Docker 图形界面 |
| `luci-i18n-dockerman-zh-cn` | 上面的中文语言包 |

> ⚠️ 老包 `luci-app-docker` **已移除** —— 它和 `dockerman` 冲突，两个一起装会导致界面错乱。

**一句话**：这是**完整的 Docker 全家桶**，不是只有一个壳。

### 4.2 Docker 数据放哪（重点）

**问题**：rootfs 只有 3G，Docker 镜像下载几个就爆了。

**解决**：首启脚本 `99-docker-flippy` 会自动找机器上最大的那个分区，把 Docker 数据搬过去。

```
探测顺序：/mnt/<磁盘>4 → /mnt/<磁盘>3 → /mnt/mmcblk1p4 → /mnt/mmcblk2p4
（p4 是你刷机后剩下的最大空闲分区）
```

- **找到了** → `ln -sf <大分区>/docker /opt/docker`（软链接）
- **没找到** → 老实回退到根分区 `/opt/docker`（能用，但空间小）

> 🛡️ **安全设计**：脚本**只做 mkdir 和软链接**，**绝不执行分区(parted/fdisk)或格式化(mkfs)**。
> 所以**没有外接盘也绝对不会把你的机器搞崩**。

### 4.3 几个关键设置（已预置，开箱即用）

| 设置 | 值 | 为什么 |
|---|---|---|
| **Docker 自启** | `auto_start=1` | ⚠️ **不设这个 dockerd 开机不自启**，LuCI 里会报 `Failed to connect to /var/run/docker.sock` |
| 数据目录 | `data-root` = 自动探测的大分区 | 防止根分区被镜像撑爆 |
| 网段 | `bip = 172.31.0.1/24` | 避开家里常用的 `192.168.1.x`，防止路由冲突 |
| 国内镜像加速 | 百度云 + 网易 | 拉镜像不用翻墙、速度快 |
| 日志轮转 | 单文件 10M，最多留 5 个 | 防止日志把磁盘写满 |

### 4.4 一个坑：配置改哪才生效

lede 的 `dockerd` 是**由 uci 驱动的**（`/etc/config/dockerd`）。

```
❌ 只改 /etc/docker/daemon.json  → 可能不生效
✅ 改 /etc/config/dockerd（或用 LuCI 界面改）→ 生效
```

脚本**两个都写了**（daemon.json 做兜底，uci 为准）。

### 4.5 刷机后怎么验证

```sh
# ① 看 Docker 装好没
docker version           # 客户端 + 服务端版本都能出来才算正常
docker info | grep "Docker Root Dir"   # 期望指向大分区，不是 /opt/docker(软链后也没事)

# ② 看数据目录挂在哪
ls -l /opt/docker        # 期望是个软链接 -> /mnt/xxx/docker/

# ③ 看中文界面在不在
ls /usr/lib/lua/luci/i18n/ | grep dockerman

# ④ 看自启开没开
uci get dockerd.globals.auto_start   # 期望 1

# ⑤ 真起一个容器试试
docker run --rm hello-world
```

### 4.6 已知注意事项

- **改完 data-root 要重启 dockerd**：
  ```sh
  /etc/init.d/dockerd stop
  rm -rf /tmp/dockerd          # 清掉旧的运行时状态
  /etc/init.d/dockerd start
  ```
- Docker 的网段是 `172.31.0.1/24`，**别让路由器/其他设备也用这个网段**。
- 首次拉镜像建议先用 `hello-world` 小镜像验证网络通了。

## 五、刷机方法

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

## 六、恢复 / 救砖

| 情况 | 恢复方法 |
|---|---|
| 刷错固件，仍能进 U-Boot | 重新用 SD 卡启动原厂/正确固件 |
| X96 Max+ 变砖 | 用 **Amlogic USB Burning Tool** + 原厂线刷包（需拆机短接或复位键进 MaskROM） |
| N1 变砖 | 用 **USB Burning Tool** + N1 原厂降级包（需拆机短接触点） |
| 配置错误无法进 LuCI | 拔电后按住复位键通电，进入 **failsafe 模式**（`http://192.168.1.1`） |

> 强烈建议刷机前备份原厂固件与 MAC 地址。

## 七、刷机后验证

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

## 八、路线图

| 阶段 | 内容 | 状态 |
|---|---|---|
| **Phase 1** | OpenWrt + Kernel + Amlogic + X96Max+ + N1 最小可启动 | ✅ 完成 |
| **Phase 2** | 千兆网口修正 + rootfs 3G + Docker 重构（flippy 方案） | ✅ 完成 |
| Phase 3 | Samba / NFS / SQM / MWAN3 / WireGuard / OpenVPN / DDNS / UPnP / WOL | 🔄 |
| Phase 4 | SmartDNS / AdGuard Home / MosDNS / OpenClash / PassWall / PassWall2 / Xray / V2Ray | 🔄 |
| Phase 5 | qBittorrent / Transmission / Aria2 / Rclone / Netdata | ⏳ |

> 原则：**先保证编译成功 → 镜像生成 → DTB 正确 → 刷机启动，再逐步加入插件。**
> 若某插件无法编译，记录原因，不强行塞入导致整个矩阵失败。

## 九、自动构建

- **主力（全量）**：Actions → `Build OpenWrt from Source (X96Max+ / N1)` → Run workflow
- **轻量（精简）**：Actions → `Build OpenWrt (X96Max+ / N1)` → Run workflow
- 产物：`*.img.gz` + `sha256sum.txt`，上传 Artifact 并发布 Release

### 9.1 为什么要 5 个多小时？（实测数据，2026-10-05）

GitHub runner 只有 **4 核 / 16GB**，而 lede 全量要编译 **1636 个编译单元**（600+ 软件包）。
实测本次 run（`37343091946`）耗时 **5h27m49s**，各阶段如下：

| 阶段 | 耗时 |
|---|---|
| 环境初始化 + 虚拟磁盘 + 拉源码 + feeds | ~8 min |
| **编译（Compile）** | **~5h02m** |
| 保存 ccache + 打包 + 上传 Release | ~7 min |

**编译阶段谁最耗时**（TOP 5）：

| 编译单元 | 耗时 | 占比 |
|---|---|---|
| **Linux 内核 6.18.55** | **255.9 min** | 🔥 **约 42%** |
| **node-v20.18.2（host 包）** | **114.4 min** | 🔥 **约 19%** |
| hostpkg/Python-3.11.13 | 19.8 min | |
| php-8.3.14 | 19.2 min | |
| Python-3.11.13 (target) | 14.8 min | |

> 👉 **光「内核 + node」两项就占了 61% 的时间**。这是全量编译绕不开的代价。

### 9.2 ccache 为什么没帮上忙？（关键真相）

本次 ccache 统计：

```
Cacheable calls: 61263 / 85770 (71.43%)
  Hits:          6599 / 61263 (10.77%)   ← 命中率只有 10.77%
  Misses:       54664 / 61263 (89.23%)
Cache size:     1.1 GiB / 5.0 GiB
```

**命中率低的三个原因**：

1. **恢复缓存的 run 失败了** —— 上次 restore 拿到的是 `openwrt-lede--37340570180`，
   是个**几乎空的缓存（360 B）**。等于这次是**冷编译**。
2. **ccache 只管 C/C++ 编译** —— 内核配置阶段、LTO 链接、Go/Rust 程序、打包压缩**全都不吃缓存**。
3. **大量 Go 程序**：OpenClash 的 mihomo、PassWall 的 xray、containerd 等，**都用 Go 自己的缓存机制**，ccache 无能为力。

> ⚠️ **血泪教训**：网上说"第一次 4h，有 ccache 后 30min"——
> **只有「编译成功过一次」之后才成立**。中途失败的话，ccache 只存到失败点之前。

### 9.3 正确的耗时预期

| 场景 | 预期耗时 |
|---|---|
| 首次冷编译（从零） | **4-5.5 小时** |
| ✅ 编译成功过 + 本次无代码变更 | **20-40 分钟** |
| 成功基线 + 只改 1 个插件 | 15-30 分钟 |
| 上次失败在中途 + 本次重跑 | 3.5-4.5 小时 |

> 🎯 **现在的状态：已经拿到「首次编译成功」的基线了**（run `37343091946`）。
> 所以**下一次纯重跑预计只要 20-40 分钟** —— 因为所有包都能命中 ccache 了。

### 9.4 超时防护（已实施，防 GitHub 6h 硬杀）

| 层级 | 设置 | 作用 |
|---|---|---|
| job | `timeout-minutes: 355` | 防 GitHub 6h 硬杀（硬杀 = 产物全丢） |
| step | `timeout-minutes: 330` | 5.5h 中断 |
| 命令 | `timeout --signal=SIGINT --kill-after=120s 320m make` | **5h20m 主动退出**（核心） |
| ccache 保存 | `actions/cache/save` + `if: always()` | **超时也保存缓存** |

**为什么要这样**：GitHub 单 job 硬限 **6 小时**，超时直接 kill、产物全丢。
所以用 `timeout 320m` 主动中断 `make`，让流程**能继续执行后面的「保存 ccache」步骤**，
下次重跑才能接着上次进度。

> 📄 详细历史数据见 [`config/BUILD-TIMING-NOTES.md`](config/BUILD-TIMING-NOTES.md)

## 十、开发说明

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
│   ├── etc/sysctl.d/99-docker.conf      # Docker bridge netfilter 开关
│   └── etc/uci-defaults/99-docker-flippy   # ⭐ Docker 首启初始化（移植自 flippy）
└── README.md
```

**修改设备范围**：编辑工作流的 `openwrt_board`（默认 `s905x3-x96max_s905d`）。
**调整 rootfs 大小**：编辑工作流的 `openwrt_size`（默认 `3072` MiB）。
**新增插件（全量）**：加入 `config/lede_master/config`，格式 `CONFIG_PACKAGE_xxx=y`。
**新增插件（轻量）**：加入 `config/imagebuilder/config`，格式 `CONFIG_PACKAGE_xxx=y`。
**新增 overlay 文件（全量）**：放入仓库根 `files/`。

> ⚠️ **踩过的坑**：lede 路线下**仓库根 `files/` 不会被自动注入**（openwrt 的 `files/` 在 `openwrt/` 目录下，
> 而仓库根在两级之外）。所以必须**在 `diy-part2.sh` 里显式 `cp -rf` 到 `package/base-files/files/`**。
> 见 `diy-part2.sh` 末尾的注入段。

## 十一、致谢

- [ophub/amlogic-s9xxx-openwrt](https://github.com/ophub/amlogic-s9xxx-openwrt) — Amlogic 打包体系
- [ophub/kernel](https://github.com/ophub/kernel) — 内核
- [unifreq/openwrt_packit](https://github.com/unifreq/openwrt_packit) — 原始打包脚本
- [haiibo/OpenWrt](https://github.com/haiibo/OpenWrt) — 项目理念来源
- OpenWrt / ImmortalWrt 上游

## 十二、许可

GPL-2.0
