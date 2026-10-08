#!/bin/bash
#=====================================================================================
# OpenWrt-X96MaxPlus-N1
# diy-part2.sh  —  feeds update 之后执行
#
# 基线：https://github.com/ophub/amlogic-s9xxx-openwrt
#       config/lede_master/diy-part2.sh （保留其全部原有定制）
# 源码：https://github.com/coolsnowwolf/lede  branch: master
#
# ⚠️ 执行时机（workflow "Load custom configuration"）：
#       cp config/lede_master/config -> openwrt/.config
#       cd openwrt/ && ./config/lede_master/diy-part2.sh <IP> <use_ccache>
#=====================================================================================

# ------------------------------- Main source started -------------------------------
#
# Set default IP address
default_ip="192.168.1.1"
ip_regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
[[ -n "${1}" && "${1}" != "${default_ip}" && "${1}" =~ ${ip_regex} ]] && {
    echo "Modify default IP address to: ${1}"
    sed -i "/lan) ipad=\${ipaddr:-/s/\${ipaddr:-\"[^\"]*\"}/\${ipaddr:-\"${1}\"}/" package/base-files/*/bin/config_generate
}

# Modify default theme (uncomment to switch)
# sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' ./feeds/luci/collections/luci/Makefile

# Add autocore support for armsr-armv8
sed -i 's/TARGET_rockchip/TARGET_rockchip\|\|TARGET_armsr/g' package/lean/autocore/Makefile

# Set etc/openwrt_release
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d)'|g" package/lean/default-settings/files/zzz-default-settings
echo "DISTRIB_SOURCEREPO='github.com/coolsnowwolf/lede'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCECODE='lede'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCEBRANCH='master'" >>package/base-files/files/etc/openwrt_release

# Set ccache
sed -i '/CONFIG_DEVEL/d' .config
sed -i '/CONFIG_CCACHE/d' .config
if [[ "${2}" == "true" ]]; then
    echo "CONFIG_DEVEL=y" >>.config
    echo "CONFIG_CCACHE=y" >>.config
    echo 'CONFIG_CCACHE_DIR="$(TOPDIR)/.ccache"' >>.config
else
    echo '# CONFIG_DEVEL is not set' >>.config
    echo '# CONFIG_CCACHE is not set' >>.config
    echo 'CONFIG_CCACHE_DIR=""' >>.config
fi

# Fix vlmcsd build error
sed -i 's|-C $(PKG_BUILD_DIR)$|CC="$(TARGET_CC_NOCACHE)"|' package/feeds/packages/vlmcsd/Makefile
#
# ------------------------------- Main source ends -------------------------------

#=====================================================================================
# X96MaxPlus-N1 : 目标插件清单
#   来源已逐项验证（coolsnowwolf/luci @openwrt-25.12 + kenzok8/small-package + lede config）
#   目标：复刻原固件全部菜单，只能多不能少
#=====================================================================================
echo "[diy-part2] Appending target plugin list to .config ..."

# --- Disable kmod-oaf (open-app-filter) ---
# Reason: its source (2025-07-03) uses del_timer_sync(), removed in Linux 6.15+.
# Build error: app_filter.c:1568: implicit declaration of function 'del_timer_sync'
# It is NOT part of any target menu item, and nothing depends on it.
sed -i 's/^CONFIG_PACKAGE_kmod-oaf=y/# CONFIG_PACKAGE_kmod-oaf is not set/' .config

cat >> .config <<'EOF'

# ==================== X96MaxPlus-N1 : Services ====================
CONFIG_PACKAGE_luci-app-passwall2=y
CONFIG_PACKAGE_luci-app-dae=y
CONFIG_PACKAGE_luci-app-ikoolproxy=y
CONFIG_PACKAGE_luci-app-v2raya=y
CONFIG_PACKAGE_luci-app-adblock=y
# ⚠️ adblock 主程序 (luci-app-adblock 只是壳, LUCI_DEPENDS:=+adblock 需显式选中;
#    否则固件里会残留 base 里的 4.1.5 老版, 与 4.5.x 前端接口不匹配 → 界面功能失效)
CONFIG_PACKAGE_adblock=y
# ⚠️ AdGuardHome 已弃用 [removed 2026-10-07]
#   原因: 与 SmartDNS 功能重叠(去广告已由 adblock 承担), 且在本固件从未初始化成功
#         (无配置文件/3000端口未起/53被 dnsmasq 占用), Go 程序常驻内存, 盒子资源有限。
#   决策: 留 SmartDNS(DNS测速加速) + adblock(去广告); 移除 AGH。
#   回滚: 改回 CONFIG_PACKAGE_luci-app-adguardhome=y 即可, 或 git revert 本次 commit
#   回滚点: main @ e45aad8ff6357c0a249671cde2881a894e663a79
# 显式写 is not set (而非删行), 防止 base config 模板残留 =y 又把它带回来
# CONFIG_PACKAGE_luci-app-adguardhome is not set
CONFIG_PACKAGE_luci-app-ssr-plus=y
CONFIG_PACKAGE_luci-app-wechatpush=y
CONFIG_PACKAGE_luci-app-timecontrol=y
CONFIG_PACKAGE_luci-app-pushbot=y
CONFIG_PACKAGE_luci-app-unblockmusic=y
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_luci-app-smartdns=y
# ⚠️ SmartDNS 主程序 (luci-app-smartdns 只是前端壳, 必须显式选中主程序;
#    否则 config 里被 base 模板显式 "# ... is not set" 关闭 → 固件残留空壳, 服务跑不起来)
#    [added 2026-10-07] 与 adblock 同款坑: 壳有、主程序被 config 显式关闭
#    回滚: 删掉下面两行即可, 或 git revert 本次 commit
#    回滚点: main @ e45aad8ff6357c0a249671cde2881a894e663a79
CONFIG_PACKAGE_smartdns=y
CONFIG_PACKAGE_smartdns-ui=y
CONFIG_PACKAGE_luci-app-xlnetacc=y
CONFIG_PACKAGE_luci-app-watchcat=y
CONFIG_PACKAGE_luci-app-UUGameAcc=y
CONFIG_PACKAGE_luci-app-udpxy=y
CONFIG_PACKAGE_luci-app-airconnect=y
CONFIG_PACKAGE_luci-app-ocserv=y
CONFIG_PACKAGE_luci-app-airplay2=y
CONFIG_PACKAGE_luci-app-npc=y
CONFIG_PACKAGE_luci-app-gost=y
CONFIG_PACKAGE_luci-app-udp2raw=y
# udp2raw 主程序：上游 luci-app-udp2raw 把依赖声明注释掉了
#   (kenzok8/small-package/luci-app-udp2raw/Makefile 里
#    "#	DEPENDS:=+udp2raw-tunnel" 是注释状态)
#   导致只编出界面、/usr/bin/udp2raw 永远不存在，
#   init 脚本里 procd_set_param command /usr/bin/udp2raw 必定失败。
#   主程序包名为 udp2raw（PROVIDES:=udp2raw-tunnel），在 small feed。
CONFIG_PACKAGE_udp2raw=y
CONFIG_PACKAGE_luci-app-tinyproxy=y
CONFIG_PACKAGE_hysteria=y
CONFIG_PACKAGE_haproxy=y

# ==================== X96MaxPlus-N1 : NAS / Storage ====================
CONFIG_PACKAGE_luci-app-kodexplorer=y
CONFIG_PACKAGE_luci-app-nfs=y
CONFIG_PACKAGE_luci-app-verysync=y
CONFIG_PACKAGE_luci-app-alist=y
# alist 主程序 (luci-app-alist 的 LUCI_DEPENDS:=+alist 会带进来, 此处显式声明防漂移)
CONFIG_PACKAGE_alist=y
# CONFIG_PACKAGE_luci-app-qbittorrent=y   # 依赖主包 qbittorrent(C++ 重包)在 lede 未默认启用, 导致 opkg 依赖缺失; 暂时禁用
CONFIG_PACKAGE_luci-app-usb-printer=y
CONFIG_PACKAGE_luci-app-p910nd=y
CONFIG_PACKAGE_luci-app-minidlna=y
CONFIG_PACKAGE_luci-app-vsftpd=y
CONFIG_PACKAGE_luci-app-transmission=y
# ⚠️ Transmission 主程序 (luci-app-transmission 只是前端壳, 必须显式选中主程序;
#    否则 config 里被 base 模板显式 "# ... is not set" 关闭 → 固件残留空壳, 服务跑不起来)
#    [added 2026-10-07] 与 adblock/smartdns 同款坑: 壳有、主程序被 config 显式关闭
#    目标: 能用(daemon) + 能开能关(web 界面) 即可
#    [fixed 2026-10-08] 移除 transmission-web: 壳 luci-app-transmission 的依赖是
#         +transmission-web-control, 与 transmission-web 互斥冲突:
#           check_conflicts_for: The following packages conflict with
#             transmission-web-control: transmission-web *
#           opkg_install_cmd: Cannot install package luci-app-transmission.
#         跟随壳的真实依赖只留 transmission-web-control。
#    回滚: 恢复 CONFIG_PACKAGE_transmission-web=y 一行即可, 或 git revert 本次 commit
#    回滚点: main @ e30c674ab1b6
CONFIG_PACKAGE_transmission-daemon=y
CONFIG_PACKAGE_transmission-web-control=y
CONFIG_PACKAGE_luci-app-mjpg-streamer=y
CONFIG_PACKAGE_luci-app-rclone=y
CONFIG_PACKAGE_luci-app-aria2=y
# ⚠️ Aria2 主程序 (luci-app-aria2 只是前端壳, 必须显式选中主程序;
#    否则 config 里被 base 模板显式 "# ... is not set" 关闭 → 固件无 aria2c 二进制,
#    LuCI 点启动必然失败 —— 这不是配置问题, 是主程序压根没编进固件)
#    [added 2026-10-07] 与 adblock/smartdns/transmission/xlnetacc 同款坑
#    回滚: 删掉下面两行即可, 或 git revert 本次 commit
#    回滚点: main @ aee43ea4bda161d5b1e4966cdc746fa985d99f71
CONFIG_PACKAGE_aria2=y
CONFIG_PACKAGE_webui-aria2=y
CONFIG_PACKAGE_luci-app-cifs-mount=y
CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_samba4-server=y
CONFIG_PACKAGE_samba4-libs=y
CONFIG_PACKAGE_samba4-client=y
CONFIG_PACKAGE_samba4-utils=y
CONFIG_PACKAGE_samba4-admin=y
CONFIG_PACKAGE_autosamba=y
CONFIG_PACKAGE_wsdd2=y
CONFIG_PACKAGE_luci-app-music-remote-center=y

# ==================== X96MaxPlus-N1 : VPN ====================
CONFIG_PACKAGE_luci-app-ssr-mudb-server=y
CONFIG_PACKAGE_shadowsocksr-libev=y
CONFIG_PACKAGE_luci-app-n2n=y
# ⚠️ SoftEther VPN 已移除   [removed 2026-10-08]
#   原因: luci-app-softethervpn 壳依赖 softethervpn-server(v4), 而 v4 的
#         softethervpn-base 与 v5 的 softethervpn5-libs 都往
#         usr/libexec/softethervpn/ 装同名文件 (vpncmd / hamcore.se2 /
#         launcher.sh) → 两套抢同一文件, 编译报错:
#           check_data_file_clashes: softethervpn-base wants /usr/bin/vpncmd
#           But that file is already provided by softethervpn5-libs
#           opkg_install_cmd: Cannot install package softethervpn-server.
#   处置: 整个 SoftEther 段删除 (壳 + v4 主程序), 不再编译该组件。
#   影响: 固件不再含 SoftEther VPN 服务端; 其余 VPN 组件
#         (ssr-mudb-server / n2n / ipsec / pptp / openvpn) 均保留不受影响。
#   回滚: 恢复下方被注释的三行即可, 或 git revert 本次 commit
#   回滚点: main @ e30c674ab1b6
# CONFIG_PACKAGE_luci-app-softethervpn=y
# CONFIG_PACKAGE_softethervpn-server=y
# CONFIG_PACKAGE_softethervpn-base=y
CONFIG_PACKAGE_libiconv-full=y
CONFIG_PACKAGE_luci-app-ipsec-server=y
CONFIG_PACKAGE_luci-app-pptp-server=y
CONFIG_PACKAGE_luci-app-openvpn-server=y

# ==================== X96MaxPlus-N1 : System / Status ====================
CONFIG_PACKAGE_luci-app-autoreboot=y
CONFIG_PACKAGE_luci-app-filetransfer=y
CONFIG_PACKAGE_luci-app-ramfree=y
CONFIG_PACKAGE_luci-app-statistics=y
CONFIG_PACKAGE_luci-app-wrtbwmon=y
CONFIG_PACKAGE_luci-app-sqm=y
CONFIG_PACKAGE_luci-app-socat=y
CONFIG_PACKAGE_luci-app-nlbwmon=y

# ==================== X96MaxPlus-N1 : 中文语言包 (i18n) ====================
# 参考机 192.168.1.60 已装, 本仓库此前遗漏, 补齐
CONFIG_PACKAGE_luci-i18n-alist-zh-cn=y
CONFIG_PACKAGE_luci-i18n-filebrowser-zh-cn=y
EOF

echo "[diy-part2] Plugin list appended. Total lines in .config: $(wc -l < .config)"

#=====================================================================================
# 注入自定义 files/ 到 base-files (OpenWrt 标准机制, 最可靠)
#   本脚本位于 <repo>/config/<branch>/diy-part2.sh, 执行时 cwd = <repo>/openwrt/
#   仓库根 = $(dirname $0)/../..  (向上两级: config/<branch>/ -> config/ -> repo root)
#   files/ 下的内容会被 base-files 包并入 rootfs 顶层 (etc/... 等)
#=====================================================================================
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ -d "${REPO_ROOT}/files" ]; then
    echo "[diy-part2] Repo root: ${REPO_ROOT}"
    echo "[diy-part2] Injecting custom files/ into package/base-files/files/ ..."
    cp -rf "${REPO_ROOT}/files/." package/base-files/files/
    # uci-defaults / init.d 脚本必须可执行
    find package/base-files/files/etc/uci-defaults -type f -exec chmod +x {} \; 2>/dev/null || true
    find package/base-files/files/etc/init.d -type f -exec chmod +x {} \; 2>/dev/null || true
    echo "[diy-part2] Injected files:"
    find package/base-files/files/etc -type f \( -name '99-*' -o -name '*docker*.json' -o -name '99-docker.conf' -o -name 'filebrowser*' -o -name 'alist*' \) 2>/dev/null | sort || true
else
    echo "[diy-part2] WARNING: ${REPO_ROOT}/files not found, skip injection"
fi

#=====================================================================================
# 可道云 (kodbox) 修复 —— 三件套   [added 2026-10-07]
#   问题: ①luci-app-kodexplorer(feeds/small) 仅外壳; config/.config 里其运行时依赖
#            (php8 / nginx-ssl) 被显式 "# ... is not set" 关闭, 编译出的固件缺运行环境
#         ②本体不在任何 feed, 靠 LuCI "手动更新" 按钮运行时下载
#         ③该按钮走 api.kodcloud.com/?app/version 取下载地址, 该 API 已失效 → 报"不存在"
#   本段: ①解除依赖的显式关闭  ②编译时注入 kodbox 本体到固件 /opt/kodexplorer
#         ③补丁 api.lua 的 to_check() 指向 GitHub 可用下载源 (恢复"手动更新"能力)
#
#   ★ 回滚方法 (任选其一):
#      a) 删除本注释块到文件末尾的全部内容 (即本段)
#      b) git revert <本次 commit sha>
#      c) git checkout ad643162ff22095799c62be06a7ffbc8edd647ae -- config/lede_master/diy-part2.sh
#   回滚点: main @ ad643162ff22095799c62be06a7ffbc8edd647ae
#          "docs: README 新增 FileBrowser/Alist 说明 + 修正章节编号"
#=====================================================================================

# ---- 1. 解除运行时依赖的显式关闭 (否则 luci-app-kodexplorer 的 select 不生效) ----
echo "[diy-part2] === 可道云: 解除依赖关闭 ==="
for pkg in php8 php8-fpm php8-fastcgi \
           php8-mod-curl php8-mod-dom php8-mod-gd php8-mod-iconv \
           php8-mod-mbstring php8-mod-opcache php8-mod-pdo \
           php8-mod-pdo-mysql php8-mod-pdo-sqlite php8-mod-session \
           php8-mod-sqlite3 php8-mod-xml php8-mod-xmlreader \
           php8-mod-xmlwriter php8-mod-zip \
           nginx-ssl unzip zoneinfo-asia; do
    sed -i "s/^# CONFIG_PACKAGE_${pkg} is not set$/CONFIG_PACKAGE_${pkg}=y/" .config
done

# ---- 2. 编译时下载 kodbox 本体并注入固件 /opt/kodexplorer (出厂即用, 重刷不丢) ----
KODBOX_VER="1.69.03"
KODBOX_URL="https://github.com/kalcaddle/kodbox/archive/refs/tags/${KODBOX_VER}.zip"
KODBOX_DST="package/base-files/files/opt/kodexplorer"
# ---- 2a. 预检: 更新 URL 必须有效 (HTTP 200)   [added 2026-10-08] ----
#   背景: 原实现只写 "if curl ...; then ... else echo WARNING 跳过注入"。
#         URL 一旦失效(上游删 tag/改名), 编译照样"成功", 但固件里根本没有
#         可道云, 且 UI 的"手动更新"会指向一个 404 —— 排查成本极高。
#   本段: 先拉最新 release tag, 再验证 zip URL 可达; 明确打印结果。
#   (不因失败而中断编译, 但会打出醒目的 ERROR 行)
KODBOX_LATEST="$(curl -fsSL --connect-timeout 15 --max-time 30 \
    https://api.github.com/repos/kalcaddle/kodbox/releases/latest 2>/dev/null \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
if [ -n "${KODBOX_LATEST}" ]; then
    echo "[diy-part2] kodbox 上游最新 release: ${KODBOX_LATEST} (内置版本 ${KODBOX_VER})"
else
    echo "[diy-part2] WARNING: 无法从 GitHub API 获取 kodbox 最新版本, 沿用内置 ${KODBOX_VER}"
fi
KODBOX_HTTP="$(curl -sIL -o /dev/null -w '%{http_code}' --connect-timeout 15 --max-time 40 \
    "${KODBOX_URL}" 2>/dev/null)"
if [ "${KODBOX_HTTP}" = "200" ]; then
    echo "[diy-part2] kodbox 下载链接校验通过: HTTP ${KODBOX_HTTP}"
else
    echo "[diy-part2] ERROR: kodbox 下载链接无效! HTTP='${KODBOX_HTTP}'  URL=${KODBOX_URL}"
    echo "[diy-part2] ERROR: 固件将不含可道云本体, UI 更新按钮也会指向失效地址"
fi
echo "[diy-part2] === 可道云: 注入 kodbox ${KODBOX_VER} ==="
if curl -fsSL -o /tmp/kodbox.zip "${KODBOX_URL}"; then
    rm -rf /tmp/kodx && mkdir -p /tmp/kodx "$KODBOX_DST"
    unzip -q -o /tmp/kodbox.zip -d /tmp/kodx
    cp -rf "/tmp/kodx/kodbox-${KODBOX_VER}/." "$KODBOX_DST/"
    rm -rf /tmp/kodbox.zip /tmp/kodx

    # ---- 2b. 剔除宿主架构(x86_64) ELF 可执行文件   [added 2026-10-08] ----
    #   回滚: 删除本小段即可, 或 git revert 本次 commit
    #   回滚点: main @ 5b49f256690cf4f86d3cefe55ae267e5dd87d78b
    #
    #   问题: kodbox 包内 app/sdks/archiveLib/bin/ 含 3 个 x86_64 ELF:
    #           rar_linux (musl) / rar + 7z (glibc)
    #         它们被注入 package/base-files/files/ 后, base-files 收尾的依赖
    #         检查会用宿主机 ldd 解析, 要求固件声明 libc.musl-x86_64.so.1 /
    #         libc.so.6 / libm.so.6 / libpthread.so.0 / libstdc++.so.6,
    #         而这些库不属于 aarch64 固件 → 编译必失败:
    #           "Package base-files is missing dependencies for the following libraries"
    #   处置: 直接删除该目录 (x86_64 二进制在 aarch64 固件上本就无法运行,
    #         属于 kodbox 自带的可选 archiver SDK; 需要时用户可自行放 aarch64 版)
    rm -rf "${KODBOX_DST}/app/sdks/archiveLib/bin"
    # 双保险: 全树兜底清除任何残留的 x86_64 ELF (幂等)
    if [ -d "$KODBOX_DST" ]; then
        find "$KODBOX_DST" -type f -exec sh -c \
            'head -c4 "$1" 2>/dev/null | grep -q "^.ELF" || exit 0; \
             od -An -tx1 -j18 -N2 "$1" 2>/dev/null | tr -d " " | grep -qi "^3e00" && rm -f "$1"' _ {} \; 2>/dev/null || true
    fi

    # ---- 2c. 修 PHP 8.3 兼容: stream_wrapper_register 类名守卫  [added 2026-10-08] ----
    #   问题: kodbox 1.69.03 的 app/autoload.php 第 263 行写死
    #           stream_wrapper_register('kodio','StreamWrapperIO');
    #         而 StreamWrapperIO 由 kodbox 自身自动加载器在运行时构造, 官方包内
    #         【没有它的类定义】(class StreamWrapperIO 全树 0 命中)。
    #         PHP 8.1 仅 warning; PHP 8.3 直接抛 TypeError:
    #           "stream_wrapper_register(): Argument #2 ($class) must be a
    #            valid class name, StreamWrapperIO given"
    #         这是 bootstrap 阶段的致命错误 → kodbox 首页打不开、
    #         "手动更新"按钮点不通, 整个可道云不可用。
    #   实证: 本固件 PHP 8.3.14。干净安装官方 kodbox 1.69.03 + 本守卫
    #         → 首页 HTTP 200, 正常进入安装向导。
    #   注意: `@` 抑制符【挡不住】 TypeError (PHP8 的 @ 不抑制异常), 必须用
    #         class_exists 真守卫 —— 已实测确认。
    #   回滚: 删除本小段即可, 或 git revert 本次 commit
    KOD_AUTOLOAD="${KODBOX_DST}/app/autoload.php"
    if [ -f "${KOD_AUTOLOAD}" ]; then
        python3 - "${KOD_AUTOLOAD}" <<'PYEOF'
import io, sys
p = sys.argv[1]
s = io.open(p, 'r', encoding='utf-8', errors='surrogateescape').read()
old = "stream_wrapper_register('kodio','StreamWrapperIO');"
new = ("if (class_exists('StreamWrapperIO', false)) {\n"
       "\tstream_wrapper_register('kodio','StreamWrapperIO');\n"
       "}")
if old in s:
    io.open(p, 'w', encoding='utf-8', errors='surrogateescape').write(
        s.replace(old, new, 1))
    print("[diy-part2]   autoload.php: PHP8.3 stream_wrapper 守卫已注入")
elif "class_exists('StreamWrapperIO'" in s:
    print("[diy-part2]   autoload.php: 守卫已存在, 跳过")
else:
    print("[diy-part2]   WARNING: autoload.php 未找到 stream_wrapper_register 锚点")
PYEOF
    else
        echo "[diy-part2] WARNING: ${KOD_AUTOLOAD} 不存在, 跳过 PHP8.3 守卫"
    fi

    echo "[diy-part2] kodbox injected: $(du -sh "$KODBOX_DST" | cut -f1)"
    echo "[diy-part2] kodbox x86_64 二进制已剔除 (archiveLib/bin)"
else
    echo "[diy-part2] WARNING: kodbox 下载失败, 跳过注入 (固件仍可用, 需手动更新)"
fi

# ---- 3. 补丁 api.lua: to_check() 直接返回 GitHub 下载地址, 修复"手动更新"按钮 ----
#   [fixed 2026-10-08] 原实现用单行 sed 只在 "function to_check()" 后插入一行
#       return {...}, 把函数体顶掉 → 插入行的嵌套花括号让 Lua 解析器找不到
#       函数的 end, 报:
#         api.lua:115: 'end' expected (to close 'function' at line 113) near 'local'
#       → api.lua 加载失败 → LuCI 菜单树 menu_json 崩溃 → 整个网页全打不开。
#   新实现: ① 用 awk 删除整个 to_check() 函数块 (含其后第一个独立 end)
#           ② 在 to_download 前插入合法单行 to_check()
#           ③ luac -p 语法校验; 失败自动回滚 .orig, 绝不把坏文件编进固件
#           ④ 无 luac 时退化为结构校验
#   回滚: 删除本段即可, 或 git revert 本次 commit
#   回滚点: main @ acdacbd871dc
KOD_API="feeds/small/luci-app-kodexplorer/luasrc/model/cbi/kodexplorer/api.lua"
if [ -f "$KOD_API" ]; then
    cp -f "$KOD_API" "${KOD_API}.orig"
    KOD_NEWFN="$(mktemp)"
    cat > "$KOD_NEWFN" <<LUAEOF
function to_check()
    return { code = 0, data = { server = { version = "${KODBOX_VER}", link = "${KODBOX_URL}" } } }
end
LUAEOF
    # ① 删除旧 to_check() 函数块
    awk '
      skip == 1 { if ($0 ~ /^end[ \t]*$/) skip = 0; next }
      /^function[ \t]+to_check[ \t]*\([ \t]*\)/ { skip = 1; next }
      { print }
    ' "$KOD_API" > "${KOD_API}.step1"
    # ② 在 to_download 之前插入新 to_check()
    if grep -q '^function[ \t]*to_download' "${KOD_API}.step1"; then
        awk -v fn="$KOD_NEWFN" '
          ins == 0 && /^function[ \t]+to_download[ \t]*\(/ {
            while ((getline l < fn) > 0) print l
            close(fn); print ""; ins = 1
          }
          { print }
        ' "${KOD_API}.step1" > "${KOD_API}.new"
    else
        # 找不到 to_download: 直接把新函数追加到文件末尾 (兜底)
        cp -f "${KOD_API}.step1" "${KOD_API}.new"
        cat "$KOD_NEWFN" >> "${KOD_API}.new"
    fi
    rm -f "${KOD_API}.step1" "$KOD_NEWFN"

    # ③ 语法校验 (有 luac 就编译检查; 失败回滚)
    PATCH_OK=0
    KOD_LUAC="$(command -v luac || command -v luac5.1 || true)"
    if [ -n "$KOD_LUAC" ]; then
        if "$KOD_LUAC" -p "${KOD_API}.new" 2>/dev/null; then
            PATCH_OK=1
            echo "[diy-part2] api.lua to_check() 已替换, luac 语法校验通过"
        else
            echo "[diy-part2] WARNING: api.lua 补丁语法校验失败, 已回滚为上游原版"
            "$KOD_LUAC" -p "${KOD_API}.new" 2>&1 | head -3 | sed 's/^/[diy-part2]   /'
        fi
    else
        # ④ 无 luac: 结构校验
        if grep -q '^function to_check()' "${KOD_API}.new" \
           && grep -q 'function to_download' "${KOD_API}.new"; then
            PATCH_OK=1
            echo "[diy-part2] api.lua to_check() 已替换 (无 luac, 结构校验通过)"
        else
            echo "[diy-part2] WARNING: api.lua 补丁结构校验失败, 已回滚为上游原版"
        fi
    fi

    if [ "$PATCH_OK" = "1" ]; then
        mv -f "${KOD_API}.new" "$KOD_API"
        grep -q "${KODBOX_URL}" "$KOD_API" \
            && echo "[diy-part2] api.lua patched OK (含下载链接)" \
            || echo "[diy-part2] WARNING: api.lua 已替换但未含下载链接, 请检查"
    else
        rm -f "${KOD_API}.new"
        cp -f "${KOD_API}.orig" "$KOD_API"
        echo "[diy-part2] api.lua 保持上游原版 (功能不受影响, 仅\"手动更新\"按钮可能不可用)"
    fi
else
    echo "[diy-part2] WARNING: $KOD_API not found, skip patch"
fi
echo "[diy-part2] === 可道云修复段完成 ==="

#=====================================================================================
# 微力同步 (luci-app-verysync) init 脚本修复   [added 2026-10-07]
#   问题: 上游 init 脚本(feeds/small/luci-app-verysync) 三处 bug, 导致
#         `service verysync start` 报 "Killed", 服务起不来:
#         ① 启动行缺 setsid → 进程是 rc.common wrapper 的子进程, 脚本收尾时被挂断杀死
#            (★ 真凶, 已在 X96Max+ 路由器实测: 手动加 setsid 即正常)
#         ② kill -9 `pgrep verysync` → 取不到 PID 时退化为 `kill -9` 无参, 异常
#         ③ [ "${enabled}" == "1" ] → == 非 POSIX, 应为 =
#   本段: 编译时 sed 修上游源码文件, 使 luci-app-verysync 包本身就带修复
#   回滚: 删除本段即可, 或 git revert 本次 commit
#   回滚点: main @ b5b19f498b49d1cb86404ad678bdcb755438a8f4
#=====================================================================================
VS_INIT="feeds/small/luci-app-verysync/root/etc/init.d/verysync"
echo "[diy-part2] === 微力同步: 修 init 脚本 ==="
if [ -f "$VS_INIT" ]; then
    cp -f "$VS_INIT" "${VS_INIT}.orig"
    # ① 启动行加 setsid (真凶修复)
    sed -i 's#\tverysync -gui-address#\tsetsid verysync -gui-address#' "$VS_INIT"
    # ② kill -9 `pgrep verysync` → pkill -9 -x verysync + return 0
    sed -i 's#\tkill -9 `pgrep verysync` >/dev/null 2>&1#\tpkill -9 -x verysync >/dev/null 2>\&1\n\treturn 0#' "$VS_INIT"
    # ③ == → = (POSIX)
    sed -i 's#\[ "${enabled}" == "1" \]#[ "${enabled}" = "1" ]#' "$VS_INIT"
    # 校验
    if grep -q 'setsid verysync' "$VS_INIT" && grep -q 'pkill -9 -x verysync' "$VS_INIT"; then
        echo "[diy-part2] verysync init patched OK"
    else
        echo "[diy-part2] WARNING: verysync init patch 不完整, 请检查上游是否改版"
    fi
else
    echo "[diy-part2] WARNING: $VS_INIT not found, skip patch"
fi
echo "[diy-part2] === 微力同步修复段完成 ==="

#=====================================================================================
# Alist 状态误报修复 (LuCI 显示"未运行"但服务实际在跑)   [added 2026-10-07]
#   问题: alist 主程序来自官方 feed(feeds/packages/net/alist), 其 init 脚本
#         procd_open_instance 未指定实例名 → procd 自动命名 "instance1";
#         而三方前端 luci-app-alist 的 basic.js 查的是 instances.alist.running,
#         名字对不上 → 服务正常运行但 LuCI 永远显示"未运行", 且无"进入界面"按钮。
#   本段: 编译时给 procd 实例命名为 alist, 与前端匹配
#         (X96Max+ 实测: sed 两行 + restart 后 ubus 实例名变 alist, LuCI 显示正常)
#   回滚: 删除本段即可, 或 git revert 本次 commit
#   回滚点: main @ 4531b283a91b70696377325287ca5e7bc12af461
#=====================================================================================
ALIST_INIT="feeds/packages/net/alist/files/alist.init"
echo "[diy-part2] === Alist: 修 procd 实例名 ==="
if [ -f "$ALIST_INIT" ]; then
    cp -f "$ALIST_INIT" "${ALIST_INIT}.orig"
    sed -i 's/^\tprocd_open_instance$/\tprocd_open_instance alist/' "$ALIST_INIT"
    sed -i 's/^\tprocd_close_instance$/\tprocd_close_instance alist/' "$ALIST_INIT"
    if grep -q 'procd_open_instance alist' "$ALIST_INIT"; then
        echo "[diy-part2] alist init patched OK"
    else
        echo "[diy-part2] WARNING: alist init patch 未命中, 请检查上游是否改版"
    fi
else
    echo "[diy-part2] WARNING: $ALIST_INIT not found, skip patch"
fi
echo "[diy-part2] === Alist 修复段完成 ==="

#=====================================================================================
# 解锁网易云 (luci-app-unblockmusic) 保存应用不生效修复   [added 2026-10-07]
#   问题: LuCI 页面勾选/取消"启用"并点"保存并应用"后, 服务不会自动启停;
#         只能手动 /etc/init.d/unblockmusic start|stop, 体验极差。
#   根因: 上游 unblockmusic.lua 未设 apply_on_parse, 且无 on_after_commit 钩子;
#         而 luci cbi.lua 的钩子执行分支(第402-405行)依赖 apply_on_parse 判定,
#         导致保存配置后不触发任何服务动作。
#   本段: 在 lua 文件 return mp 之前注入 apply_on_parse=false + on_after_commit,
#         使"保存并应用"按钮自动 restart unblockmusic。
#         (X96Max+ 实测: 取消勾选保存→进程停; 勾选保存→进程自动起)
#   回滚: 删除本段即可, 或 git revert 本次 commit
#   回滚点: main @ 7f187daf95e382949449b818fe3ccc63b9383735
#=====================================================================================
UM_LUA="feeds/small/luci-app-unblockmusic/luasrc/model/cbi/unblockmusic/unblockmusic.lua"
echo "[diy-part2] === 解锁网易云: 注入 apply 钩子 ==="
if [ -f "$UM_LUA" ]; then
    cp -f "$UM_LUA" "${UM_LUA}.orig"
    if grep -q "on_after_commit" "$UM_LUA"; then
        echo "[diy-part2] unblockmusic 已有钩子, 跳过"
    else
        sed -i 's#^return mp$#mp.apply_on_parse = false\nfunction mp.on_after_commit(self)\n    luci.sys.call("\/etc\/init.d\/unblockmusic restart >\/dev\/null 2>\&1")\nend\n\nreturn mp#' "$UM_LUA"
        if grep -q "on_after_commit" "$UM_LUA"; then
            echo "[diy-part2] unblockmusic 钩子注入 OK"
        else
            echo "[diy-part2] WARNING: unblockmusic 钩子注入失败 (return mp 未命中?)"
        fi
    fi
else
    echo "[diy-part2] WARNING: $UM_LUA not found, skip patch"
fi
echo "[diy-part2] === 解锁网易云修复段完成 ==="

#=====================================================================================
# pushbot (luci-app-pushbot) 修复与校验   [added 2026-10-07]
#   上游: feeds/small/luci-app-pushbot  (kenzok8/small-package, 每次 feeds update 拉最新)
#   版本: v6.01-r13 (2026-09-27 发布, 上游活跃维护)
#
#   背景(已在 X96Max+ 实测):
#     - 旧固件的 pushbot 症状: 「服务起不来 / 启动后自动关闭」。
#     - 实测确认根因之一: 主程序 enable_detection() 在读取到
#       pushbot_enable=0 时会主动调用 /etc/init.d/pushbot stop 自杀
#       (上游 v6.01 起为「总开关关闭则清理服务」的有意设计)。
#       => 只要总开关保持 1 即可正常运行(用户已在路由器实测通过)。
#     - 本段做两件事, 保证「开箱即用」:
#       ① init 脚本防御补丁: 上游 `kill -9 `pgrep ...`` 在「当前无 pushbot 进程」
#          时,命令替换为空 -> 退化成无参 `kill -9`, 在部分 busybox 上会刷
#          "kill: not enough arguments" 干扰日志。改为先取 PID 判空再杀,
#          逻辑等价且静默安全。
#       ② 编译期校验: 打印实际版本号 + 关键行, 便于在 Actions 日志一眼确认
#          拉到的确实是新版、反引号等特殊字符完好。
#
#   回滚: 删除本段即可, 或 git revert 本次 commit
#   回滚点: main @ 7f187daf95e382949449b818fe3ccc63b9383735
#=====================================================================================
PB_DIR="feeds/small/luci-app-pushbot"
PB_INIT="${PB_DIR}/root/etc/init.d/pushbot"
PB_MAIN="${PB_DIR}/root/usr/bin/pushbot/pushbot"
echo "[diy-part2] === pushbot: 校验版本 + init 防御补丁 ==="
if [ -f "$PB_INIT" ] && [ -f "$PB_MAIN" ]; then
    # ---- 版本打印 (编译日志可见) ----
    PB_VER="$(grep -m1 '^PKG_VERSION:=' "${PB_DIR}/Makefile" 2>/dev/null | cut -d= -f2)"
    PB_REL="$(grep -m1 '^PKG_RELEASE:=' "${PB_DIR}/Makefile" 2>/dev/null | cut -d= -f2)"
    echo "[diy-part2] pushbot 版本: ${PB_VER}-r${PB_REL} (期望 >= 6.01-r13)"

    # ---- ① init 防御补丁 ----
    #  目标行(上游): \tkill -9 `pgrep -f "/usr/bin/pushbot/pushbot"` 2>/dev/null
    #  替换为:       \tPB_PIDS=$(pgrep -f "/usr/bin/pushbot/pushbot"); [ -n "$PB_PIDS" ] && kill -9 $PB_PIDS 2>/dev/null
    #  用 sed 的 ` 匹配反引号需转义, 这里改用「整行按锚点重写」策略:
    #  以 'kill -9' 开头且含 pgrep 的行使之变为带判空的写法。
    cp -f "$PB_INIT" "${PB_INIT}.orig"
    awk '
        /kill -9 .*pgrep/ && !/PB_PIDS/ {
            match($0, /^[ \t]*/); ind = substr($0, 1, RLENGTH)
            print ind "PB_PIDS=$(pgrep -f \"/usr/bin/pushbot/pushbot\")"
            print ind "[ -n \"$PB_PIDS\" ] && kill -9 $PB_PIDS 2>/dev/null"
            next
        }
        { print }
    ' "${PB_INIT}.orig" > "$PB_INIT"
    chmod 755 "$PB_INIT"
    if grep -q 'PB_PIDS=' "$PB_INIT"; then
        echo "[diy-part2] pushbot init 防御补丁 OK"
    else
        echo "[diy-part2] WARNING: pushbot init 补丁未命中, 上游脚本结构可能已变"
    fi

    # ---- ② 关键行校验 (只读) ----
    echo "[diy-part2] pushbot init stop() 片段:"
    grep -n 'PB_PIDS\|pushbot exit' "$PB_INIT" | head -5
    echo "[diy-part2] pushbot 主程序总开关自杀逻辑 (应含反引号调用 stop):"
    grep -n 'init.d/pushbot stop' "$PB_MAIN" | head -3
else
    echo "[diy-part2] WARNING: $PB_DIR 未找到 (feeds 可能未拉取成功), 跳过 pushbot 段"
fi
echo "[diy-part2] === pushbot 修复段完成 ==="

#=====================================================================================
# adblock 开箱即用修复   [added 2026-10-07]
#   上游: adblock 本体来自 feeds/packages/net/adblock (v4.5.8-r3, 官方活跃维护)
#         luci-app-adblock 前端来自 feeds/luci (coolsnowwolf/luci, v4.5.8-r3)
#
#   问题(X96Max+ 实测现象):
#     - LuCI 里 adblock 界面能打开, 但启用后完全无效果。
#     - opkg 显示: adblock 4.1.5-9 (2022 年老版) + luci-app-adblock 4.5.4-r1 (新版)
#       → 前后端版本错位, 界面调用的接口主程序没有。
#     - uci: adb_enabled='0' → 总开关关闭, 服务不跑
#     - /etc/init.d/adblock status → "active with no instances"
#
#   根因(已确认):
#     本仓库 diy-part2.sh 原先只写了 CONFIG_PACKAGE_luci-app-adblock=y (壳),
#     主程序 CONFIG_PACKAGE_adblock 未显式选中 → 固件未编入新版主程序,
#     残留 base 的 4.1.5 老版 → 前后端错位。
#     (已在本段上方补 CONFIG_PACKAGE_adblock=y)
#
#   本段做两件事:
#     ① uci-defaults 注入: 首启把 adb_enabled 设为 1 (开箱即用)。
#        仅首启执行一次; 用户后续手动改动不会被覆盖(uci-defaults 只跑一次)。
#     ② 编译期校验: 打印 adblock 本体/前端版本, 确认 ≥ 4.5.8 且前后端一致。
#
#   回滚: 删除本段 + 上方 CONFIG_PACKAGE_adblock=y 行即可, 或 git revert
#   回滚点: main @ cc8aac8
#=====================================================================================
ADB_DIR="feeds/packages/net/adblock"
ADB_LUCI="feeds/luci/applications/luci-app-adblock"
echo "[diy-part2] === adblock: 默认启用 + 版本校验 ==="
if [ -f "${ADB_DIR}/Makefile" ]; then
    ADB_VER="$(grep -m1 '^PKG_VERSION:=' "${ADB_DIR}/Makefile" 2>/dev/null | cut -d= -f2)"
    ADB_REL="$(grep -m1 '^PKG_RELEASE:=' "${ADB_DIR}/Makefile" 2>/dev/null | cut -d= -f2)"
    echo "[diy-part2] adblock 本体版本: ${ADB_VER}-${ADB_REL} (期望 >= 4.5.8)"
    if [ -f "${ADB_LUCI}/Makefile" ]; then
        ADBL_VER="$(grep -m1 '^PKG_VERSION:=' "${ADB_LUCI}/Makefile" 2>/dev/null | cut -d= -f2)"
        echo "[diy-part2] luci-app-adblock 前端版本: ${ADBL_VER} (应与本体一致)"
    fi

    # ---- ① uci-defaults 默认启用 ----
    #  文件已在仓库 files/etc/uci-defaults/99-adblock-default-enable,
    #  由本脚本下方「注入 files/ 到 base-files」段统一 cp 进 rootfs。
    UCD_DIR="package/base-files/files/etc/uci-defaults"
    if [ -f "${UCD_DIR}/99-adblock-default-enable" ]; then
        echo "[diy-part2] adblock uci-defaults 已就位: ${UCD_DIR}/99-adblock-default-enable"
    else
        # 兜底: 若 files/ 注入未覆盖到(仓库结构变动), 这里直接生成
        mkdir -p "$UCD_DIR"
        cat > "${UCD_DIR}/99-adblock-default-enable" <<'UCDEOF'
#!/bin/sh
# adblock 开箱即用: 首次启动时确保总开关开启。
# 仅在选项不存在时写入, 不覆盖用户已保存的配置。
[ -x /etc/init.d/adblock ] || exit 0
cur="$(uci -q get adblock.global.adb_enabled)"
if [ -z "$cur" ]; then
    uci -q set adblock.global.adb_enabled='1'
    uci -q commit adblock
fi
exit 0
UCDEOF
        chmod 755 "${UCD_DIR}/99-adblock-default-enable"
        echo "[diy-part2] adblock uci-defaults 兜底生成: ${UCD_DIR}/99-adblock-default-enable"
    fi
else
    echo "[diy-part2] WARNING: ${ADB_DIR}/Makefile 未找到 (feeds 未拉取?), 跳过 adblock 段"
fi
echo "[diy-part2] === adblock 修复段完成 ==="

#=====================================================================================
# SmartDNS 启用修复 (双保险)   [added 2026-10-07]
#   问题: 只写了 CONFIG_PACKAGE_luci-app-smartdns=y (壳), 主程序在 base config
#         里被显式 "# ... is not set" 关闭 → 固件残留空壳, 服务跑不起来。
#         (与 adblock 同款坑; SmartDNS 为本固件的 DNS 加速方案, AGH 已弃用)
#
#   本段: 解除 base config 中几条显式关闭 (sed 就地改写, 幂等)。
#         与本脚本上方 .config 追加段形成双保险:
#           ① 上方 cat >> .config 追加 CONFIG_PACKAGE_smartdns=y / smartdns-ui=y
#           ② 本段 sed 掉 config 模板里的 is not set
#         二者叠加, 无论 config 归一化顺序如何都能生效。
#
#   回滚: 删除本段 + 上方 smartdns 三行即可, 或 git revert 本次 commit
#   回滚点: main @ e45aad8ff6357c0a249671cde2881a894e663a79
#=====================================================================================
echo "[diy-part2] === SmartDNS: 解除 base config 显式关闭 ==="
for pkg in luci-app-smartdns luci-app-smartdns_INCLUDE_WebUI smartdns smartdns-ui; do
    sed -i "s/^# CONFIG_PACKAGE_${pkg} is not set$/CONFIG_PACKAGE_${pkg}=y/" .config
done
# 校验: 4 项应全部为 =y
SD_OK=1
for pkg in luci-app-smartdns smartdns smartdns-ui; do
    grep -q "^CONFIG_PACKAGE_${pkg}=y" .config || { echo "[diy-part2] WARNING: ${pkg} 未变为 =y"; SD_OK=0; }
done
[ "$SD_OK" = "1" ] && echo "[diy-part2] SmartDNS 主程序启用校验: OK" || echo "[diy-part2] WARNING: SmartDNS 启用校验未全部通过, 请查上游 config 结构"
echo "[diy-part2] === SmartDNS 修复段完成 ==="

#=====================================================================================
# Transmission 启用修复 (双保险)   [added 2026-10-07] [fixed 2026-10-08]
#   问题: 只写了 CONFIG_PACKAGE_luci-app-transmission=y (壳), 主程序
#         transmission-daemon 在 base config 里被显式
#         "# ... is not set" 关闭 → 固件残留空壳, 服务起不来。
#         (与 adblock/smartdns/kodexplorer 同款坑)
#
#   本段: 解除 base config 中几条显式关闭 (sed 就地改写, 幂等)。
#         与本脚本上方 .config 追加段形成双保险:
#           ① 上方 cat >> .config 追加 CONFIG_PACKAGE_transmission-daemon=y
#                                          CONFIG_PACKAGE_transmission-web-control=y
#           ② 本段 sed 掉 config 模板里的 is not set
#         二者叠加, 无论 config 归一化顺序如何都能生效。
#
#   [fixed 2026-10-08] 把关掉 transmission-web 也纳入 sed 目标:
#         壳 luci-app-transmission 依赖 +transmission-web-control, 与
#         transmission-web 互斥。原 sed 列表含 transmission-web, 会把冲突包
#         又激活回去 → 必须移除, 改用 transmission-web-control。
#
#   回滚: 删除本段 + 上方 transmission 两行即可, 或 git revert 本次 commit
#   回滚点: main @ e30c674ab1b6
#=====================================================================================
echo "[diy-part2] === Transmission: 解除 base config 显式关闭 ==="
for pkg in luci-app-transmission transmission-daemon transmission-web-control; do
    sed -i "s/^# CONFIG_PACKAGE_${pkg} is not set$/CONFIG_PACKAGE_${pkg}=y/" .config
done
# 显式确保互斥包 transmission-web 保持关闭 (防 base 模板残留或依赖漂移重新激活)
sed -i "s/^CONFIG_PACKAGE_transmission-web=y$/# CONFIG_PACKAGE_transmission-web is not set/" .config
# 校验: 3 项应全部为 =y
TR_OK=1
for pkg in luci-app-transmission transmission-daemon transmission-web-control; do
    grep -q "^CONFIG_PACKAGE_${pkg}=y" .config || { echo "[diy-part2] WARNING: ${pkg} 未变为 =y"; TR_OK=0; }
done
[ "$TR_OK" = "1" ] && echo "[diy-part2] Transmission 主程序启用校验: OK" || echo "[diy-part2] WARNING: Transmission 启用校验未全部通过, 请查上游 config 结构"
echo "[diy-part2] === Transmission 修复段完成 ==="

#=====================================================================================
# 迅雷快鸟 (luci-app-xlnetacc) 启用 + 首启预置   [added 2026-10-07]
#   来源: feeds/small/luci-app-xlnetacc (kenzok8/small-package, v1.1, 每次 feeds update 拉最新)
#   依赖: +jshn +curl +openssl-util +luci-compat (均在 config 里 =y, 无问题)
#
#   问题(两层):
#     ① 编译层: 只写了 CONFIG_PACKAGE_luci-app-xlnetacc=y (壳), 但 config:5377
#        有显式 "# CONFIG_PACKAGE_luci-app-xlnetacc is not set" → 固件里根本没这个包,
#        界面都看不到。(与 adblock/smartdns/transmission 同款坑)
#     ② 运行层: init 脚本第24行有"静默退出"逻辑 ——
#        ( [enabled==0] || [down_acc==0 && up_acc==0] || [账号/密码/网卡任一为空] ) && return 2
#        => 未填账号/未选网卡/未开开关时, 服务主动拒绝启动(非故障)。
#
#   本段做两件事:
#     ① sed 解除 base config 的显式关闭 (与上方 .config 追加形成双保险)
#     ② uci-defaults 首启预置: 总开关 enabled=1 + 网卡 wan (缩短手填步骤)
#        ★ 不预置账号/密码 —— 公开仓写密码不安全, 刷机后由用户在界面填一次。
#
#   回滚: 删除本段即可, 或 git revert 本次 commit
#   回滚点: main @ a57df608203a400866d02ca62f3e0d0f2ed96781
#=====================================================================================
echo "[diy-part2] === 迅雷快鸟: 解除显式关闭 + 首启预置 ==="
# ① 解除 base config 显式关闭
for pkg in luci-app-xlnetacc; do
    sed -i "s/^# CONFIG_PACKAGE_${pkg} is not set$/CONFIG_PACKAGE_${pkg}=y/" .config
done
grep -q "^CONFIG_PACKAGE_luci-app-xlnetacc=y" .config \
    && echo "[diy-part2] xlnetacc 包启用校验: OK" \
    || echo "[diy-part2] WARNING: xlnetacc 未变为 =y, 请查上游 config 结构"

# ② 首启预置 (只写开关和网卡, 不碰账号密码)
UCD_DIR="package/base-files/files/etc/uci-defaults"
mkdir -p "$UCD_DIR"
cat > "${UCD_DIR}/99-xlnetacc-default-enable" <<'UCDEOF'
#!/bin/sh
# 迅雷快鸟开箱即用: 首次启动确保总开关开启 + 出口网卡为 wan。
# 仅在选项缺失时写入, 不覆盖用户已保存的配置。
# ★ 账号/密码需用户在 LuCI 界面手动填写 (安全考虑, 不预置)。
[ -x /etc/init.d/xlnetacc ] || exit 0
[ -f /etc/config/xlnetacc ] || exit 0
cur="$(uci -q get xlnetacc.general.enabled)"
if [ -z "$cur" ] || [ "$cur" = "0" ]; then
    uci -q set xlnetacc.general.enabled='1'
fi
net="$(uci -q get xlnetacc.general.network)"
if [ -z "$net" ]; then
    uci -q set xlnetacc.general.network='wan'
fi
uci -q commit xlnetacc
exit 0
UCDEOF
chmod 755 "${UCD_DIR}/99-xlnetacc-default-enable"
echo "[diy-part2] xlnetacc uci-defaults 已生成: ${UCD_DIR}/99-xlnetacc-default-enable"
echo "[diy-part2] === 迅雷快鸟修复段完成 ==="

#=====================================================================================
# ⚠️ 已知遗留 (未修, 待用户决策): 上游 uci-defaults/luci-xlnetacc 用了 ucitrack
#   本固件 luci 为混合版, ucitrack 机制可能不存在 → 该上游脚本首行
#   `delete ucitrack.@xlnetacc[-1]` 可能报错(但 exit 0 兜底, 危害低)。
#   若实测界面"保存应用"不触发服务动作, 再回来处理此处。
#=====================================================================================

#=====================================================================================
# Aria2 启用修复 (双保险)   [added 2026-10-07]
#   问题: 只写了 CONFIG_PACKAGE_luci-app-aria2=y (壳), 主程序 aria2 / webui-aria2
#         在 base config 里被显式 "# ... is not set" 关闭 → 固件无 aria2c 二进制,
#         LuCI 点启动必然失败(不是配置问题, 是主程序没编进去)。
#         (与 adblock/smartdns/transmission/xlnetacc 同款坑)
#
#   本段: 解除 base config 中几条显式关闭 (sed 就地改写, 幂等)。
#         与本脚本上方 .config 追加段形成双保险:
#           ① 上方 cat >> .config 追加 CONFIG_PACKAGE_aria2=y / webui-aria2=y
#           ② 本段 sed 掉 config 模板里的 is not set
#
#   回滚: 删除本段 + 上方 aria2 两行即可, 或 git revert 本次 commit
#   回滚点: main @ aee43ea4bda161d5b1e4966cdc746fa985d99f71
#=====================================================================================
echo "[diy-part2] === Aria2: 解除 base config 显式关闭 ==="
for pkg in luci-app-aria2 aria2 webui-aria2; do
    sed -i "s/^# CONFIG_PACKAGE_${pkg} is not set$/CONFIG_PACKAGE_${pkg}=y/" .config
done
# 校验
AR_OK=1
for pkg in luci-app-aria2 aria2; do
    grep -q "^CONFIG_PACKAGE_${pkg}=y" .config || { echo "[diy-part2] WARNING: ${pkg} 未变为 =y"; AR_OK=0; }
done
[ "$AR_OK" = "1" ] && echo "[diy-part2] Aria2 主程序启用校验: OK" || echo "[diy-part2] WARNING: Aria2 启用校验未通过, 请查上游 config 结构"
echo "[diy-part2] === Aria2 修复段完成 ==="

#=====================================================================================
# SoftEther VPN 段已整体移除   [removed 2026-10-08]
#   原先此处有"双保险"段: 用 sed 解除 base config 里 softethervpn-base /
#   softethervpn-server / luci-app-softethervpn 的显式关闭, 强行使 v4 三件套 =y。
#   该做法正是编译失败的元凶: v4 的 softethervpn-base 与 v5 的 softethervpn5-libs
#   争抢 usr/libexec/softethervpn/ 下同名文件 (vpncmd / hamcore.se2 / launcher.sh),
#   导致 package/install 阶段报:
#     check_data_file_clashes: softethervpn-base wants /usr/bin/vpncmd
#     But that file is already provided by softethervpn5-libs
#     opkg_install_cmd: Cannot install package softethervpn-server.
#
#   处置: 本段删除, 且上方 .config 追加段里的 softethervpn 三行也已注释,
#         上下两处都不再启用 SoftEther → 彻底不编该组件, 冲突消失。
#   影响: 固件不含 SoftEther VPN; 其余 VPN 组件保持不变。
#   回滚: 恢复本段并取消上方三行注释即可, 或 git revert 本次 commit
#   回滚点: main @ e30c674ab1b6
#=====================================================================================

#=====================================================================================
# Docker 对齐参考机 192.168.1.60   [added 2026-10-08]
#
# 参考机 .60 (flippy/armvirt) 的 docker 行为:
#   Storage Driver : overlay2   (经典 image store, 目录 image/overlay2)
#   data-root      : /mnt/mmcblk2p4/docker   (ext4)
#   log-driver     : json-file + log-opts max-size=10m, max-file=5
#   containerd     : 1.7.x, 未启用 containerd snapshotter
#
# 本固件 (.100.1, LEDE / dockerd 29.6.1) 实测异常:
#   ① Storage Driver = overlayfs / io.containerd.snapshotter.v1
#      → Docker 29 默认强制启用 containerd image store
#        (dockerd 日志: "Starting daemon with containerd snapshotter integration enabled")
#        → image save/load/export 行为与参考机不同, 是"镜像导入导出"类问题的根源
#   ② /tmp/dockerd/daemon.json (真正生效的配置) 里【没有】log-driver / log-opts
#      → 容器日志无限增长。根因见 ③
#   ③ 【核心 bug】dockerd 的 init 脚本只读 UCI, 生成 /tmp/dockerd/daemon.json;
#      它【不会】读 /etc/docker/daemon.json。原 99-docker-flippy 写了一份带日志轮转的
#      daemon.json 却从未设置 alt_config_file, 那份文件被完全忽略。
#      (该脚本注释"lede dockerd 以 uci 为准, daemon.json 为辅"是误解)
#      实测: /etc/uci-defaults/ 里 99-docker-flippy 执行到第③步(建 /opt/docker 软链)
#            后就中断了, /etc/docker/daemon.json 根本没有生成。
#
# 修复 (构建期, 幂等):
#   A. 给 uci-defaults 脚本补 alt_config_file + storage_driver + snapshotter=false
#      → init 脚本 process_config() 会 ln -s 我们的 daemon.json 到
#        /tmp/dockerd/daemon.json, 使其成为唯一权威配置
#      ! 注意: alt_config_file 是【整体替换】而非合并 —— init 脚本一旦走这条路,
#        UCI 里的 data_root/bip/registry_mirrors 全部失效。所以 daemon.json
#        必须自带完整键集, 否则 data-root 会掉回 /tmp/lib/docker (tmpfs, 重启即失)。
#        (已在真机验证过这个坑)
#   B. 新增 99-docker-align: 首启兜底生成完整 daemon.json 并挂上 alt_config_file
#
# 实现说明: A 段用 python3 做文本插入, 不用 sed/awk —— 经实测, sed 的 s|||
#   表达式在 "shell -> sed" 多层引号下会静默失配(rc=0 但不插入), awk 同理。
#   python3 在 Ubuntu runner 上必然存在, 引号完全可控。A3 的 sed 已实测通过。
#
# data-root 为何不在构建期烤死:
#   99-docker-flippy 在首启时按实际数据分区动态生成 data-root
#   (X96Max+ → /mnt/mmcblk1p4, N1 → 对应磁盘), 故 99-docker-align 在其之后
#   (同目录按文件名排序) 兜底补齐, 并复用 /opt/docker 软链结果。
#
# 回滚: 删除本段 + 删除 files/etc/uci-defaults/99-docker-align,
#       或 git revert 本次 commit
#=====================================================================================
echo "[diy-part2] === Docker 对齐参考机 .60 ==="

UCD_DOCKER="${REPO_ROOT}/files/etc/uci-defaults/99-docker-flippy"

if [ -f "${UCD_DOCKER}" ]; then
    # ---- A1 + A2 + A3. 用 python3 一次完成三处插入 ----
    #   A1/A2: 往 uci batch 块插入 alt_config_file / storage_driver
    #   A3   : 往它生成的 daemon.json 模板插入 storage-driver / containerd-snapshotter
    #   全部用 python3 而非 sed/awk —— 经实测 sed 的 s||| 表达式在
    #   "shell -> sed" 多层引号下会静默失配(rc=0 却不插入)。
    python3 - "${UCD_DOCKER}" <<'PYEOF'
import io, sys, os, json, re
p = sys.argv[1]

if not os.path.exists(p):
    print("[diy-part2]   WARNING: %s not found" % p)
    sys.exit(1)

s = io.open(p, 'r', encoding='utf-8', newline='').read()
changed = []

# ---- A1/A2: uci batch 块 ----
if 'alt_config_file' not in s:
    anchor = "set dockerd.globals.iptables='true'"
    if anchor in s:
        s = s.replace(anchor,
                      anchor + "\n"
                      "set dockerd.globals.alt_config_file='/etc/docker/daemon.json'\n"
                      "set dockerd.globals.storage_driver='overlay2'", 1)
        changed.append('uci:alt_config_file+storage_driver')
    else:
        print("[diy-part2]   WARNING: iptables anchor not found in uci block")
else:
    changed.append('uci:already-present')

# ---- A3: daemon.json 模板 ----
if 'containerd-snapshotter' not in s:
    pat = '  "log-level": "warn",'
    if pat in s:
        s = s.replace(pat,
                      pat + "\n"
                      '  "storage-driver": "overlay2",\n'
                      '  "features": { "containerd-snapshotter": false },', 1)
        changed.append('json:storage-driver+snapshotter')
    else:
        print("[diy-part2]   WARNING: log-level anchor not found in daemon.json template")
else:
    changed.append('json:already-present')

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print("[diy-part2]   changed: %s" % ", ".join(changed))

# ---- 校验: 解析脚本里真实生成的 daemon.json 模板 ----
# 路径用 \S* 宽容匹配 (上游可能写成 /tmp/... 或其他位置);
# 找不到或解析失败只告警、不中止构建 —— 真正的兜底是 99-docker-align,
# 它在首启时会写出完整正确的 daemon.json。
m = re.search(r'cat > \S*daemon\.json <<EOF\r?\n(.*?)\r?\nEOF', s, re.S)
if not m:
    print("[diy-part2]   WARN: daemon.json heredoc not located in template "
          "(99-docker-align 仍会在首启兜底)")
else:
    body = m.group(1).replace('${DATA_ROOT}', '/tmp/__placeholder__/')
    try:
        obj = json.loads(body)
    except Exception as e:
        print("[diy-part2]   WARN: generated daemon.json is not valid JSON (%s); "
              "99-docker-align 会在首启兜底" % e)
    else:
        need = ['data-root', 'log-driver', 'log-opts', 'storage-driver',
                'features', 'registry-mirrors']
        missing = [k for k in need if k not in obj]
        if missing:
            print("[diy-part2]   WARN: daemon.json missing keys: %s" % missing)
        elif obj.get('storage-driver') != 'overlay2':
            print("[diy-part2]   WARN: storage-driver != overlay2")
        elif obj.get('features', {}).get('containerd-snapshotter') is not False:
            print("[diy-part2]   WARN: containerd-snapshotter is not false")
        else:
            print("[diy-part2]   OK: daemon.json template valid, "
                  "storage-driver=overlay2, snapshotter=false")
PYEOF
    PY_RC=$?
    if [ "${PY_RC}" != "0" ]; then
        echo "[diy-part2] WARNING: 99-docker-flippy 对齐脚本返回 rc=${PY_RC}, 请检查"
    fi
else
    echo "[diy-part2] WARNING: ${UCD_DOCKER} 未找到, 跳过 A 段 (仍由 99-docker-align 兜底)"
fi

# ---- B. 首启兜底脚本 ----
ALIGN="${REPO_ROOT}/files/etc/uci-defaults/99-docker-align"
if [ -d "${REPO_ROOT}/files/etc/uci-defaults" ]; then
    cat > "${ALIGN}" <<'ALIGN_EOF'
#!/bin/sh
#======================================================================================
# Docker 对齐参考机 192.168.1.60   (first boot, 幂等, 非破坏)
#   由 config/lede_master/diy-part2.sh 生成, 请勿手工编辑
#
# 目的: 让 dockerd 真正采用 /etc/docker/daemon.json, 并关闭 Docker 29 默认强制的
#       containerd image store, 回到参考机 .60 的经典 overlay2 + 日志轮转行为。
#
# 关键: dockerd 的 init 脚本只读 UCI, 不读 /etc/docker/daemon.json。
#       alt_config_file 会让 init 脚本 `ln -s` 该文件到 /tmp/dockerd/daemon.json,
#       且为【整体替换】而非合并 —— 故本文件必须自带完整键集。
#======================================================================================

# ---- ① 定位数据分区 (与 99-docker-flippy 同逻辑, 优先复用其软链) ----
DATA_ROOT=""
if [ -L /opt/docker ]; then
    DATA_ROOT="$(readlink -f /opt/docker)"
fi

if [ -z "${DATA_ROOT}" ] || [ ! -d "${DATA_ROOT}" ]; then
    ROOT_PTNAME=$(df / | tail -n1 | awk '{print $1}' | awk -F '/' '{print $3}')
    case "$ROOT_PTNAME" in
        mmcblk?p[1-9]*)    DISK=$(echo "$ROOT_PTNAME" | sed 's/p[0-9]*$//'); PT_PRE="${DISK}p" ;;
        nvme?n?p[1-9]*)    DISK=$(echo "$ROOT_PTNAME" | sed 's/p[0-9]*$//'); PT_PRE="${DISK}p" ;;
        [hsv]d[a-z][1-9]*) DISK=$(echo "$ROOT_PTNAME" | sed 's/[0-9]*$//');  PT_PRE="${DISK}"  ;;
        *)                 DISK=$(echo "$ROOT_PTNAME" | sed 's/[0-9]*$//');  PT_PRE="${DISK}"  ;;
    esac
    for cand in "/mnt/${PT_PRE}4" "/mnt/${PT_PRE}3" "/mnt/mmcblk1p4" "/mnt/mmcblk2p4"; do
        [ -n "$cand" ] || continue
        if mountpoint -q "$cand" 2>/dev/null || grep -q " ${cand} " /proc/mounts 2>/dev/null; then
            DATA_ROOT="${cand}/docker"
            break
        fi
    done
fi

if [ -z "${DATA_ROOT}" ]; then
    DATA_ROOT="/opt/docker"
    echo "[99-docker-align] WARNING: 未找到大容量数据分区, 回退 ${DATA_ROOT}"
fi
mkdir -p "${DATA_ROOT}" 2>/dev/null
DATA_ROOT="${DATA_ROOT%/}/"

# ---- ② 写出完整 daemon.json (权威配置, 必须自带全部键) ----
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "data-root": "${DATA_ROOT}",
  "bip": "172.31.0.1/24",
  "iptables": true,
  "ip6tables": false,
  "log-level": "warn",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "5"
  },
  "storage-driver": "overlay2",
  "features": {
    "containerd-snapshotter": false
  },
  "registry-mirrors": [
    "https://mirror.baidubce.com/",
    "https://hub-mirror.c.163.com"
  ]
}
EOF

# ---- ③ 让 init 脚本采用它 (整体替换语义, 见文件头说明) ----
uci -q batch <<EOF
set dockerd.globals.alt_config_file='/etc/docker/daemon.json'
set dockerd.globals.storage_driver='overlay2'
commit dockerd
EOF

# ---- ④ 生效 ----
if [ -x /etc/init.d/dockerd ]; then
    /etc/init.d/dockerd enable
    /etc/init.d/dockerd restart
fi

# ---- ⑤ 自检 ----
D=$(pidof dockerd 2>/dev/null | awk '{print $1}')
if [ -n "$D" ]; then
    logger -t 99-docker-align "dockerd up: $(docker info 2>/dev/null | grep -i 'Storage Driver' | head -1)"
fi
exit 0
ALIGN_EOF
    chmod 0755 "${ALIGN}"
    echo "[diy-part2] 99-docker-align 已生成: ${ALIGN}"
else
    echo "[diy-part2] WARNING: ${REPO_ROOT}/files/etc/uci-defaults 不存在, 跳过 B 段"
fi

echo "[diy-part2] === Docker 对齐段完成 ==="

#=====================================================================================
# 老式 init 脚本补 running()  —— 修 LuCI "一直运行中、关不了"   [added 2026-10-08]
#
# 现象: uuplugin_luci / pushbot / xlnetacc / kodexplorer 在 LuCI 里永远显示
#       "运行中", 点停止无效。
#
# 根因 (不是少了函数那么简单):
#   /etc/rc.common 用【命令白名单】派发:
#       ALL_COMMANDS="${ALL_COMMANDS} ${EXTRA_COMMANDS}"
#       list_contains ALL_COMMANDS "$action" || action=help
#       $action "$@"
#   而 "running" 只在 USE_PROCD 分支里被 extra_command 注册 (rc.common:125-126)。
#   这 4 个脚本都是老式 rc.common (无 USE_PROCD) → 没有 running 命令
#   → action 退化成 help → 打印约 392 字符语法提示并 **exit 0**
#   → LuCI 拿到非空输出判定"运行中"; 点停止也走不通同一套语义 → 关不掉。
#
#   实测(修前): uuplugin_luci running -> exit=0 输出长度=402
#               pushbot       running -> exit=0 输出长度=396
#               xlnetacc      running -> exit=0 输出长度=397
#               kodexplorer   running -> exit=0 输出长度=400
#
# 已试过但【无效】的做法 (留作记录, 别再走弯路):
#   ① 仅注入 running() 函数而不声明 EXTRA_COMMANDS
#      —— rc.common 白名单不认, 仍然退化成 help (实测 exit=0 输出 392 字符)。
#   ② 给脚本加 USE_PROCD=1
#      —— 会同时把 start()/stop() 覆盖成 procd 语义, 破坏老式启动逻辑。
#   ③ 用 shell 的 `{ echo ...; } >> file` 拼 running() 函数体
#      —— BusyBox echo 不解释 \t (写成字面量 "\t"), 且多行块拼接不可靠,
#         函数体可能整个丢失 → 命令未定义 → exit=127。已踩到, 故本段改用 python3。
#
# 正确修法: 只加两处, 不碰 start()/stop(), 不用 USE_PROCD:
#     EXTRA_COMMANDS="${EXTRA_COMMANDS} running"
#     EXTRA_HELP="\t running ..."
#     running() { pgrep -f "<进程特征>" >/dev/null 2>&1; }
#   实测(修后): 未运行 -> exit=1 且输出为空 (LuCI 正确显示"已停止")
#
# 进程特征来源: 各脚本自身 start() 里真正拉起的可执行路径。
# 回滚: 删除本段即可, 或 git revert 本次 commit
#=====================================================================================
echo "[diy-part2] === 老式 init 脚本补 running() ==="
RUNFIX="${REPO_ROOT}/files/etc/uci-defaults/99-init-running-fix"
if [ -d "${REPO_ROOT}/files/etc/uci-defaults" ]; then
    cat > "${RUNFIX}" <<'RUNFIX_EOF'
#!/bin/sh
#======================================================================================
# 给老式 init 脚本补 running 子命令 (first boot, 幂等)   [generated by diy-part2.sh]
#
# 原理见 diy-part2.sh 对应注释: rc.common 命令白名单只认 EXTRA_COMMANDS 注册的
# 命令, 所以必须同时声明 EXTRA_COMMANDS 并定义 running()。
#
# 文本插入用 python3 整块写入 —— 不用 shell echo 拼多行函数 (BusyBox echo 不解释
# \t, 且块拼接不可靠会导致函数体丢失 -> exit=127)。
#======================================================================================

FIX=/usr/libexec/init-running-fix.py
cat > "$FIX" <<'PYEOF'
import io, sys, os

# (脚本路径, 描述, 进程特征, 是否组合判定)
TARGETS = [
    ("/etc/init.d/uuplugin_luci", "uuplugin_luci", "/usr/bin/uuplugin/uuplugin", False),
    ("/etc/init.d/pushbot",       "pushbot",       "/usr/bin/pushbot/pushbot",   False),
    ("/etc/init.d/xlnetacc",      "xlnetacc",      "xlnetacc.sh",                False),
    # kodexplorer 是 nginx + php-fpm 组合: 任一缺失即视为未运行 (如实反映半死状态)
    ("/etc/init.d/kodexplorer",   "kodexplorer",   None,                         True),
]

MARK = "[init-running-fix]"

def patch(path, name, pattern, combo):
    if not os.path.isfile(path):
        print("%s skip (missing): %s" % (MARK, path))
        return
    s = io.open(path, "r", encoding="utf-8", errors="surrogateescape").read()
    if "EXTRA_COMMANDS" in s and "running()" in s:
        print("%s already patched: %s" % (MARK, name))
        return
    if "EXTRA_COMMANDS=.*running" in s:
        print("%s partially patched, repairing: %s" % (MARK, name))

    # 备份一次
    bak = path + ".orig-runningfix"
    if not os.path.exists(bak):
        io.open(bak, "w", encoding="utf-8", errors="surrogateescape").write(s)

    # 去掉可能存在的半截补丁, 保证幂等
    lines = s.split("\n")
    keep = []
    skip = False
    for ln in lines:
        if MARK in ln:
            skip = True
            continue
        if skip:
            # 跳过上一次补丁的行, 直到函数或声明结束
            if ln.startswith("running()") or ln.startswith("EXTRA_") or ln.strip() == "}":
                continue
            if ln.strip() == "":
                continue
            skip = False
        keep.append(ln)
    s = "\n".join(keep).rstrip("\n")

    if combo:
        body = ("\n\n# %s LuCI \u72b6\u6001\u5224\u5b9a: \u58f0\u660e running \u547d\u4ee4\u5e76\u5b9e\u73b0\n"
                'EXTRA_COMMANDS="${EXTRA_COMMANDS} running"\n'
                '# %s nginx \u4e0e php-fpm \u5fc5\u987b\u90fd\u5728, \u5426\u5219\u89c6\u4e3a\u672a\u8fd0\u884c\n'
                '# \u7528 pidof \u800c\u975e pgrep -f: \u5b9e\u6d4b pgrep -f\n'
                "#   \"php-fpm: master process (/var/etc/kodexplorer\" \u56e0\u6a21\u5f0f\u542b\u62ec\u53f7\u800c\u5931\u914d\n"
                "#   (\u8fd4\u56de 1), \u4f46\u8fdb\u7a0b\u786e\u5b9e\u5b58\u5728; pidof \u7cbe\u786e\u5339\u914d\u8fdb\u7a0b\u540d\u53ef\u9760\u3002\n"
                "running() {\n"
                "\tpidof nginx >/dev/null 2>&1 || return 1\n"
                "\tpidof php8-fpm >/dev/null 2>&1 || return 1\n"
                "\treturn 0\n"
                "}\n") % (MARK, MARK)
    else:
        body = ("\n\n# %s LuCI \u72b6\u6001\u5224\u5b9a: \u58f0\u660e running \u547d\u4ee4\u5e76\u5b9e\u73b0\n"
                'EXTRA_COMMANDS="${EXTRA_COMMANDS} running"\n'
                "running() {\n"
                "\tpgrep -f '%s' >/dev/null 2>&1\n"
                "}\n") % (MARK, pattern)

    io.open(path, "w", encoding="utf-8", errors="surrogateescape").write(s + body)
    print("%s patched: %s" % (MARK, name))

for path, name, pattern, combo in TARGETS:
    patch(path, name, pattern, combo)
PYEOF
chmod 0755 "$FIX"

# 语法自检 -> 逐个应用, 失败即回滚该文件
for s in uuplugin_luci pushbot xlnetacc kodexplorer; do
    [ -f "/etc/init.d/$s" ] || continue
    [ -f "/etc/init.d/$s.orig-runningfix" ] || cp -f "/etc/init.d/$s" "/etc/init.d/$s.orig-runningfix"
done

python3 "$FIX"

# 应用后逐个语法校验, 坏的回滚
for s in uuplugin_luci pushbot xlnetacc kodexplorer; do
    S="/etc/init.d/$s"
    [ -f "$S" ] || continue
    if sh -n "$S" 2>/dev/null; then
        echo "[init-running-fix] syntax OK: $s"
    else
        cp -f "$S.orig-runningfix" "$S"
        echo "[init-running-fix] ERROR: syntax failed, rolled back: $s"
    fi
done

exit 0
RUNFIX_EOF
    chmod 0755 "${RUNFIX}"
    echo "[diy-part2] 99-init-running-fix 已生成: ${RUNFIX}"
else
    echo "[diy-part2] WARNING: ${REPO_ROOT}/files/etc/uci-defaults 不存在, 跳过"
fi
echo "[diy-part2] === running() 修复段完成 ==="

#=====================================================================================
# adblock 预置 DNS 后端与下载工具 + transmission 默认启用   [added 2026-10-08]
#
# 全部改动均已在真机 (192.168.100.1, OpenWrt 24.10.5 / PHP 8.3.14) 验证通过。
#
# ── A. adblock 起不来的真因: 两个配置项都不会自动探测 ──
#   实测日志 (修前):
#     user.err adblock: dns backend not found, please set 'adb_dns' manually
#     user.err adblock: download utility with SSL support not found,
#                       please set 'adb_fetchcmd' manually
#   procd 侧:  "running": false, "exit_code": 1
#   说明: adblock 4.5.8 不会自动探测 DNS 后端, 也不会自动挑 SSL 下载工具,
#         所以 adb_enabled=1 也没用 —— 它以 exit_code=1 立刻退出。
#   修复后实测:
#     adblock_status: enabled
#     "blocklist with overall 325 429 blocked domains loaded successfully"
#     active_feeds: adguard, adguard_tracking, certpl
#     blocklist 325432 行 / 9.6MB 写入 /tmp/dnsmasq.<cfg>.d/adb_list.overall
#
#   注意: adblock 是 procd 管理的【一次性任务】(procd_set_param command
#         "${adb_script}" "${action}"), 跑完下载即退出。所以 `running` 返回
#         非 0 属于设计行为, 不是故障; 健康指标是 adblock.runtime.json 里的
#         adblock_status 与 blocked_domains。
#
# ── B. transmission 默认不启用 ──
#   实测: transmission.@transmission[0].enabled='0' → 服务不注册 procd 实例,
#         pidof 为空; 置 1 后 pid=25404, running rc=0 正常。
#   本段只补 enabled, 路径 (config_dir/download_dir) 保持上游默认, 用户可在
#   LuCI 自行修改 —— 不覆盖用户已配的值。
#
# 回滚: 删除本段 + 删除 files/etc/uci-defaults/99-adblock-and-services 即可
#=====================================================================================
echo "[diy-part2] === adblock 预置 + transmission 默认启用 ==="
ADB_FIX="${REPO_ROOT}/files/etc/uci-defaults/99-adblock-and-services"
if [ -d "${REPO_ROOT}/files/etc/uci-defaults" ]; then
    cat > "${ADB_FIX}" <<'ADBFIX_EOF'
#!/bin/sh
#======================================================================================
# adblock DNS 后端/下载工具预置 + transmission 默认启用
#   (first boot, 幂等, 非破坏)   [generated by diy-part2.sh]
#
# 只填空缺: 已有用户配置一律不覆盖。
#======================================================================================

# ── A. adblock ────────────────────────────────────────────────────────────────
if [ -f /etc/config/adblock ] || uci -q show adblock >/dev/null 2>&1; then
    # 确保 global section 存在
    uci -q get adblock.global >/dev/null 2>&1 || uci -q add adblock global

    # A1. DNS 后端: 未设置则按本机实际在跑的 DNS 选一个
    if [ -z "$(uci -q get adblock.global.adb_dns)" ]; then
        if pidof dnsmasq >/dev/null 2>&1 || [ -x /usr/sbin/dnsmasq ]; then
            uci -q set adblock.global.adb_dns='dnsmasq'
        elif [ -x /usr/sbin/unbound ]; then
            uci -q set adblock.global.adb_dns='unbound'
        elif [ -x /usr/sbin/smartdns ]; then
            uci -q set adblock.global.adb_dns='smartdns'
        fi
        logger -t adblock-init "preset adb_dns=$(uci -q get adblock.global.adb_dns)"
    fi

    # A2. 下载工具: 必须支持 SSL (https)。优先 curl
    if [ -z "$(uci -q get adblock.global.adb_fetchcmd)" ]; then
        for fc in curl uclient-fetch wget-ssl wget; do
            if command -v "$fc" >/dev/null 2>&1; then
                uci -q set adblock.global.adb_fetchcmd="$fc"
                break
            fi
        done
        logger -t adblock-init "preset adb_fetchcmd=$(uci -q get adblock.global.adb_fetchcmd)"
    fi

    # A3. 报告目录 (report 动作需要, 否则报 nonexistent directory)
    mkdir -p /tmp/adblock-report /tmp/adblock-backup 2>/dev/null

    uci -q commit adblock
fi

# ── B. transmission 默认启用 ──────────────────────────────────────────────────
if [ -f /etc/config/transmission ] || uci -q show transmission >/dev/null 2>&1; then
    uci -q get transmission.@transmission[0] >/dev/null 2>&1 || uci -q add transmission transmission
    # 只在未设置时补 1, 不覆盖用户显式关闭
    if [ -z "$(uci -q get transmission.@transmission[0].enabled)" ]; then
        uci -q set transmission.@transmission[0].enabled='1'
        logger -t transmission-init "preset enabled=1"
    fi
    # 目录兜底 (init 脚本也会建, 这里提前建避免首启竞态)
    cfg_dir=$(uci -q get transmission.@transmission[0].config_dir)
    [ -n "$cfg_dir" ] && mkdir -p "$cfg_dir" 2>/dev/null
    dl_dir=$(uci -q get transmission.@transmission[0].download_dir)
    [ -n "$dl_dir" ] && mkdir -p "$dl_dir" 2>/dev/null
    uci -q commit transmission
fi

exit 0
ADBFIX_EOF
    chmod 0755 "${ADB_FIX}"
    echo "[diy-part2] 99-adblock-and-services 已生成: ${ADB_FIX}"
else
    echo "[diy-part2] WARNING: ${REPO_ROOT}/files/etc/uci-defaults 不存在, 跳过"
fi
echo "[diy-part2] === adblock/transmission 段完成 ==="

#=====================================================================================
# UU 加速器 (UU GameAcc) 二进制架构修复   [added 2026-10-08]
#
# 【致命缺陷】固件里内嵌的 uuplugin 是 x86_64 版, 在 aarch64 上完全无法执行。
#
# 真机证据 (192.168.100.1, aarch64_generic):
#   $ /usr/bin/uuplugin/uuplugin
#   timeout: failed to run command '...': Exec format error
#   $ strings /usr/bin/uuplugin/uuplugin | grep -c x86_64
#   15                                    <- x86_64 特征
#   包信息: luci-app-UUGameAcc  Architecture: all   <- 只装了 LuCI 壳
#
# 为什么"看起来在跑": /etc/init.d/uuplugin_luci 的 start() 用
#   /usr/bin/uuplugin/uuplugin >/dev/null 2>&1 &
# 后台启动并把 stderr 全部丢弃, 所以 Exec format error 被吞掉,
# 进程起不来但 LuCI 仍显示"已启用" -> 插件形同虚设。
#
# 修复: 构建期从上游拉 aarch64 包, 用其中的正确二进制替换。
#   来源: https://github.com/ttc0419/uuplugin  (打包网易官方 uuplugin)
#   资产: uuplugin_latest_aarch64_cortex-a53.ipk
#         (aarch64_generic 归属 cortex-a53; 官方支持 aarch64/arm/mipsel/x86_64)
#   包内: usr/bin/uuplugin            (4355568 B, aarch64)
#         usr/bin/xtables-nft-multi   (1987304 B)
#         etc/init.d/uuplugin
#         etc/uu.conf                 (version=v12.1.18, 原固件为 v2.13.4)
#
# 真机修复后实测:
#   - 二进制可执行, 进程正常 (pid 28920/28924)
#   - xtables-nft-multi 报错归零 (修前: "/usr/bin/uuplugin/xtables-nft-multi: not found")
#   - nft 规则真实建立: table ip/ip6 XU_ACC_MAIN_{filter,mangle,nat} 共 6 张
#   - /etc/init.d/uuplugin_luci running -> exit=0 outlen=0
#
# !! 路径细节: 程序实际调用的是 /usr/bin/uuplugin/xtables-nft-multi
#    (uuplugin 子目录), 而包里放在 /usr/bin/xtables-nft-multi。
#    两个路径都必须放一份, 否则 nft 规则建不起来。
#
# 注意: 加速器用 nft 配防火墙规则 (不是老的 iptables)。
#       本固件 firewall4/nftables 1.1.6, 已实测可用。
#
# 回滚: 删除本段即可, 或 git revert 本次 commit
#=====================================================================================
echo "[diy-part2] === UU 加速器 aarch64 二进制修复 ==="
UU_VER="latest"
UU_ARCH="aarch64_cortex-a53"
UU_URL="https://github.com/ttc0419/uuplugin/releases/download/${UU_VER}/uuplugin_${UU_VER}_${UU_ARCH}.ipk"
UU_DST="package/base-files/files"

# 预检下载链接有效性
UU_HTTP="$(curl -sIL -o /dev/null -w '%{http_code}' --connect-timeout 15 --max-time 40 "${UU_URL}" 2>/dev/null)"
if [ "${UU_HTTP}" = "200" ]; then
    echo "[diy-part2] UU 包链接校验通过: HTTP ${UU_HTTP}"
else
    echo "[diy-part2] ERROR: UU 包链接无效 HTTP='${UU_HTTP}' URL=${UU_URL}"
    echo "[diy-part2] ERROR: 固件将保留不可用的 x86_64 uuplugin (UU加速器无法工作)"
fi

if curl -fsSL --connect-timeout 20 --max-time 300 -o /tmp/uuplugin.ipk "${UU_URL}"; then
    rm -rf /tmp/uux && mkdir -p /tmp/uux/a /tmp/uux/d
    ( cd /tmp/uux/a && tar -xzf /tmp/uuplugin.ipk 2>/dev/null )
    if [ -f /tmp/uux/a/data.tar.gz ]; then
        tar -xzf /tmp/uux/a/data.tar.gz -C /tmp/uux/d 2>/dev/null
        UU_BIN="$(find /tmp/uux/d -name uuplugin -type f | head -1)"
        UU_XT="$(find /tmp/uux/d -name xtables-nft-multi -type f | head -1)"

        if [ -n "${UU_BIN}" ]; then
            # 剔除可能残留的 x86_64 版本 (base-files 收尾的依赖检查会对
            # x86_64 ELF 报 "missing dependencies for libraries" -> 编译失败,
            # 与 kodbox 那次同因, 所以必须先删旧的再放新的)
            rm -rf "${UU_DST}/usr/bin/uuplugin"
            mkdir -p "${UU_DST}/usr/bin/uuplugin"
            cp -f "${UU_BIN}" "${UU_DST}/usr/bin/uuplugin/uuplugin"
            chmod 0755 "${UU_DST}/usr/bin/uuplugin/uuplugin"

            # xtables-nft-multi: 两个路径都要 (程序实际找 uuplugin 子目录那份)
            if [ -n "${UU_XT}" ]; then
                cp -f "${UU_XT}" "${UU_DST}/usr/bin/uuplugin/xtables-nft-multi"
                chmod 0755 "${UU_DST}/usr/bin/uuplugin/xtables-nft-multi"
            fi

            # 包内 uu.conf: 程序默认读 /etc/uu.conf (init 脚本传的就是这个路径),
            # 同时兼容 uuplugin 子目录那份 —— 两处都放, 与真机验证状态一致。
            UU_CONF="$(find /tmp/uux/d -name uu.conf -type f | head -1)"
            if [ -n "${UU_CONF}" ]; then
                mkdir -p "${UU_DST}/etc"
                cp -f "${UU_CONF}" "${UU_DST}/etc/uu.conf"
                cp -f "${UU_CONF}" "${UU_DST}/usr/bin/uuplugin/uu.conf"
                echo "[diy-part2] UU uu.conf 已放置: $(cat "${UU_CONF}" | tr '\n' ' ')"
            fi

            # 包自带 /etc/init.d/uuplugin (USE_PROCD=1, 忽略 uci enabled) 与固件原有的
            # /etc/init.d/uuplugin_luci (LuCI 壳, 读 uci enabled) 语义冲突:
            #   luci 壳: enabled=0 -> stop(), =1 -> 启动
            #   包 init: 无条件启动
            # 真机已验证采用【luci 壳那套】(保留 LuCI 开关), 故这里不装包的 init,
            # 只提供二进制 + xtables + conf。用户可在 LuCI 界面自行开关。
            # (若将来想改用包自带 init, 取消下面注释并同步删除 uuplugin_luci)
            # UU_INIT="$(find /tmp/uux/d -path '*/init.d/uuplugin' -type f | head -1)"
            # if [ -n "${UU_INIT}" ]; then
            #     mkdir -p "${UU_DST}/etc/init.d"
            #     cp -f "${UU_INIT}" "${UU_DST}/etc/init.d/uuplugin"
            #     chmod 0755 "${UU_DST}/etc/init.d/uuplugin"
            # fi

            # 校验: 确认放进去的是 aarch64 而不是 x86_64
            X86N="$(strings "${UU_DST}/usr/bin/uuplugin/uuplugin" 2>/dev/null | grep -c x86_64)"
            echo "[diy-part2] UU uuplugin 已替换: $(du -h "${UU_DST}/usr/bin/uuplugin/uuplugin" | cut -f1), x86_64 特征数=${X86N} (期望 0)"
            if [ "${X86N}" != "0" ]; then
                echo "[diy-part2] ERROR: 放入的 UU 二进制仍含 x86_64 特征, 架构可能不对!"
            fi
        else
            echo "[diy-part2] WARNING: UU 包内未找到 uuplugin 二进制"
        fi
    else
        echo "[diy-part2] WARNING: UU ipk 解包失败 (data.tar.gz 缺失)"
    fi
    rm -rf /tmp/uux /tmp/uuplugin.ipk
else
    echo "[diy-part2] WARNING: UU 包下载失败, 保留原 x86_64 版本 (UU加速器将不可用)"
fi
echo "[diy-part2] === UU 加速器修复段完成 ==="

#=====================================================================================
# 各插件 LuCI 界面加入「如何使用」说明   [added 2026-10-08]
#
# 背景: 这些插件装上后界面上只有开关，用户不知道该怎么用。尤其是
#       UU 加速器 (付费服务, 需手机 App 登录 + 绑定设备) 和
#       adblock (需先配 DNS 后端/下载工具), 光看开关必然困惑。
#
# 做法: 首启写一个 uci-defaults, 往各插件的界面文件里插入一段说明区块。
#       - 老式 Lua CBI (.htm 模板): 追加 <fieldset> 说明块
#       - 新式 ucode / JS 视图: 不硬改 (结构差异大, 风险高), 只做提示文件
#       幂等: 已含标记则跳过; 已有用户改动不覆盖 (只在缺失时插入)
#
# 回滚: 删除本段 + files/etc/uci-defaults/99-plugin-usage-guide 即可
#=====================================================================================
echo "[diy-part2] === 插件 UI 加入使用说明 ==="
UIFIX="${REPO_ROOT}/files/etc/uci-defaults/99-plugin-usage-guide"
if [ -d "${REPO_ROOT}/files/etc/uci-defaults" ]; then
    cat > "${UIFIX}" <<'UIFIX_EOF'
#!/bin/sh
#======================================================================================
# 各插件 LuCI 界面「如何使用」说明注入 (first boot, 幂等, 非破坏)
#   [generated by diy-part2.sh]
#
# 文本插入统一用 python3 —— 与其它段落一致, 避免 shell 引号/转义问题。
#======================================================================================

GUIDE=/usr/libexec/plugin-usage-guide.py
cat > "$GUIDE" <<'PYEOF'
# -*- coding: utf-8 -*-
# 各插件 LuCI 界面「如何使用」说明注入器
# 注意: 本文件内不要使用 \uXXXX 转义写在注释里 —— Python 在注释中会把它
#       当普通字符, 但若紧跟十六进制字符会被吞掉导致语法错误。直接用 UTF-8。
import io, os

MARK = 'plugin-usage-guide'

def insert_after_last(path, close_tag, block, mark_id):
    if not os.path.isfile(path):
        print('  skip (missing): %s' % path)
        return
    s = io.open(path, 'r', encoding='utf-8', errors='surrogateescape').read()
    if mark_id in s:
        print('  already has guide: %s' % path)
        return
    idx = s.rfind(close_tag)
    if idx == -1:
        print('  WARN no %s in %s; appending' % (close_tag, path))
        s = s + '\n' + block
    else:
        end = idx + len(close_tag)
        s = s[:end] + block + s[end:]
    io.open(path, 'w', encoding='utf-8', errors='surrogateescape').write(s)
    print('  inserted guide: %s' % path)

def box(title, items, notes=None, mark_id=MARK):
    h = ['', '<fieldset class="cbi-section" data-guide="%s">' % mark_id,
         '\t<legend>%s</legend>' % title,
         '\t<div style="line-height:1.7em;font-size:13px">',
         '\t\t<ol style="margin:6px 0 6px 18px;padding:0">']
    for it in items:
        h.append('\t\t\t<li>%s</li>' % it)
    h.append('\t\t</ol>')
    if notes:
        h.append('\t\t<p><b>注意事项</b></p>')
        h.append('\t\t<ul style="margin:6px 0 6px 18px;padding:0">')
        for n in notes:
            h.append('\t\t\t<li>%s</li>' % n)
        h.append('\t\t</ul>')
    h.append('\t</div>')
    h.append('</fieldset>')
    h.append('')
    return '\n'.join(h)

# ---------- UU 加速器 ----------
insert_after_last(
    '/usr/lib/lua/luci/view/uuplugin/uuplugin_status.htm', '</fieldset>',
    box('<%:How to use%>',
        ['先在手机上的「UU加速器」App 登录账号，并开通主机/路由器加速权限。',
         '回到本页勾选 <b>启用</b>，点 <b>保存并应用</b>。状态应变为绿色 <b>运行中</b>。',
         '在手机 App 里选「路由器加速 / 主机加速」，按提示 <b>绑定本台路由器</b>（同一局域网内可发现）。',
         '绑定成功后 App 内会显示已连接，再在 App 里选择要加速的游戏即可。'],
        ['UU GameAcc 是 <b>付费服务</b>，本插件只是路由器端客户端；<b>能运行 ≠ 已加速</b>。',
         '若状态一直显示“运行中”但你从未绑定过，多半是 <b>残留进程</b> 造成的假状态：先点停用保存，再重新勾选启用。',
         '依赖 <code>kmod-tun</code>，并通过 <code>nft</code> 下发防火墙规则（表名 <code>XU_ACC_MAIN_*</code>）。规则建立失败则加速不生效。',
         '加速仅对 <b>经过本路由器</b> 的流量有效；纯旁路由或双层 NAT 环境可能需在 App 内切换连接方式。'], MARK))

# ---------- Adblock ----------
insert_after_last(
    '/usr/lib/lua/luci/view/adblock/status.htm', '</fieldset>',
    box('<%:How to use%>',
        ['首次使用先确认 <b>DNS 后端</b> 已选（本固件首启已自动预置为 <code>dnsmasq</code>）。',
         '确认 <b>下载工具</b> 已选（首启预置为 <code>curl</code>）。缺这两项会报 dns backend not found / download utility with SSL support not found，服务会以 exit_code=1 立刻退出。',
         '在 <b>Blocklist</b> 选要用的规则源（如 adguard / certpl），点 <b>保存并应用</b>。',
         '点 <b>重新启动</b> 触发一次拉取；完成后在状态页可看到已拦截域名数。'],
        ['adblock 是 <b>一次性任务</b>（procd 管理）：跑完下载就退出，所以“未运行” <b>不代表故障</b>。健康指标看状态页的 status / 拦截数。',
         '拦截依赖 DNS：客户端必须把 DNS 指向本路由器，否则不生效。',
         '规则文件较大（全量约 9-10MB），写入 <code>/tmp</code>，重启后需重新拉取。'], MARK))

# ---------- 迅雷快鸟 ----------
insert_after_last(
    '/usr/lib/lua/luci/view/xlnetacc/status.htm', '</fieldset>',
    box('<%:How to use%>',
        ['在设置页填写迅雷账号与密码，并选择要使用的网络接口（通常是 WAN）。',
         '勾选 <b>下行加速 / 上行加速</b>，保存并应用。',
         '到本页确认运行状态与日志。'],
        ['仅支持 <b>迅雷会员</b> 账号；非会员或密码错误会在日志里报鉴权失败。',
         '该服务依赖迅雷服务器可达；网络不通时会反复重连。',
         '加速效果与区域/运营商有关，不一定全部地区有效。'], MARK))

# ---------- udp2raw 隧道 ----------
insert_after_last(
    '/usr/lib/lua/luci/view/udp2raw/status.htm', '</fieldset>',
    box('<%:How to use%>',
        ['在 <b>Servers</b> 标签添加一个服务端（需自己有对端跑着 udp2raw 服务端）。',
         '在 <b>General</b> 标签启用并选择要代理的本地端口与对端地址。',
         '保存应用后到本页确认连接状态。'],
        ['udp2raw 本身不提供加速，它只是把 UDP 伪装成 TCP/ICMP 以绕过 QoS 限速；<b>对端必须有服务端</b>。',
         '典型用法是与加速/代理工具配合，单独开启不会有任何效果。'], MARK))

print('[plugin-usage-guide] done')

PYEOF
chmod 0755 "$GUIDE"

python3 "$GUIDE" 2>&1

exit 0
UIFIX_EOF
    chmod 0755 "${UIFIX}"
    echo "[diy-part2] 99-plugin-usage-guide 已生成: ${UIFIX}"
else
    echo "[diy-part2] WARNING: ${REPO_ROOT}/files/etc/uci-defaults 不存在, 跳过"
fi
echo "[diy-part2] === 插件说明段完成 ==="

#=====================================================================================
# PushBot 默认启用 + 清理「误启用的备份脚本」   [added 2026-10-08]
#
# ── A. PushBot 启动即退: 是它自己的保护逻辑, 不是坏了 ──
#   实测 (/usr/bin/pushbot/pushbot 第 484-492 行):
#     function enable_detection(){
#         get_config pushbot_enable
#         [ "$pushbot_enable" = "0" ] && `/etc/init.d/pushbot stop` && return 0
#     }
#   即: 检测到 pushbot_enable=0 就【自杀】。固件默认正是 pushbot_enable='0',
#   所以进程起来几秒就没了, 日志里连错误都没有 —— 极易误判为"插件坏了"。
#
#   实测修复后 (pushbot_enable=1):
#     start -> pid=3028 ; running exit=0 ; 20s 后仍存活
#     stop  -> pid 空, running=1 ; start -> pid=4294, running=0
#     /tmp/pushbot/ 运行态文件正常生成 (ipAddress / firewall_mode / ...)
#   依赖 curl/wget/jq 均已内置。
#
# ── B. 备份脚本被当成正式 init 脚本执行 (真缺陷) ──
#   rc.d 里存在指向 *.orig 的符号链接, 开机时会被当脚本执行:
#     /etc/rc.d/S99pushbot.orig  -> ../init.d/pushbot.orig
#     /etc/rc.d/S99verysync.orig -> ../init.d/verysync.orig
#     /etc/rc.d/K10verysync.orig -> ../init.d/verysync.orig
#   实测危害 (verysync): 两个脚本内容完全相同 (diff 为空), 但
#     a) verysync.orig 的 start() 第一行就是 `stop`
#     b) 同名排序下 verysync.orig 排在 verysync 之后
#   => 开机时先启动 verysync, 随后 verysync.orig 把它 stop 掉再起一个,
#      等于每次开机都无故重启一次服务; 且 /etc/init.d/verysync.orig 会绕过
#      仓库 diy-part2.sh 里给 verysync 打的 setsid 修复补丁。
#   pushbot 同理: S99pushbot.orig 与 S99pushbot 两个都跑, 各自输出
#      "pushbot is starting now ..." (logread 可见两条)。
#
#   处置: 首启清理 /etc/rc.d 下所有指向 *.orig/*.bak/*.disabled/*.old/*.save
#         的链接; 并把这些备份文件移出 /etc/init.d (改名加前缀, 保留可回溯)。
#
# 回滚: 删除本段 + files/etc/uci-defaults/99-pushbot-and-stray-cleanup
#=====================================================================================
echo "[diy-part2] === PushBot 启用 + 清理误启用备份脚本 ==="
PBFIX="${REPO_ROOT}/files/etc/uci-defaults/99-pushbot-and-stray-cleanup"
if [ -d "${REPO_ROOT}/files/etc/uci-defaults" ]; then
    cat > "${PBFIX}" <<'PBFIX_EOF'
#!/bin/sh
#======================================================================================
# PushBot 默认启用 + 清理 rc.d 中误启用的备份脚本
#   (first boot, 幂等, 非破坏)   [generated by diy-part2.sh]
#======================================================================================

# ── A. PushBot: 默认启用 ──────────────────────────────────────────────────────
# 注意: 不能无条件覆盖 —— 若用户已显式设为 0 (表示不想跑), 尊重用户选择。
if [ -f /etc/config/pushbot ] || uci -q show pushbot >/dev/null 2>&1; then
    uci -q get pushbot.pushbot >/dev/null 2>&1 || uci -q add pushbot pushbot
    if [ -z "$(uci -q get pushbot.pushbot.pushbot_enable)" ]; then
        uci -q set pushbot.pushbot.pushbot_enable='1'
        logger -t pushbot-init "preset pushbot_enable=1"
    fi
    # 首次设置 sleeptime (插件默认轮询间隔)
    [ -z "$(uci -q get pushbot.pushbot.sleeptime)" ] && uci -q set pushbot.pushbot.sleeptime='60'
    uci -q commit pushbot
fi

# ── B. 清理误启用的备份脚本 ───────────────────────────────────────────────────
# B1. 删除 rc.d 里指向备份文件的符号链接 (这些会被开机执行)
for l in /etc/rc.d/*; do
    [ -L "$l" ] || continue
    t="$(readlink "$l")"
    case "$t" in
        *.orig|*.bak|*.disabled|*.old|*.save)
            rm -f "$l"
            logger -t stray-init-cleanup "removed stray rc.d link: $(basename $l)"
            ;;
    esac
done

# B2. 把 /etc/init.d 下的备份文件改名, 避免被 rc.common/其它工具误认为服务
#     (加 .disabled-suffix, 并移到 /etc/init.d-backup/, 保留可回溯)
mkdir -p /etc/init.d-backup 2>/dev/null
for f in /etc/init.d/*.orig /etc/init.d/*.bak /etc/init.d/*.disabled /etc/init.d/*.old /etc/init.d/*.save; do
    [ -f "$f" ] || continue
    b="$(basename "$f")"
    mv -f "$f" "/etc/init.d-backup/$b" 2>/dev/null \
        && logger -t stray-init-cleanup "moved out of init.d: $b"
done

# B3. 顺带清理 rc.d 里已失效的悬空链接 (指向不存在文件的)
for l in /etc/rc.d/*; do
    [ -L "$l" ] || continue
    [ -e "$l" ] && continue
    rm -f "$l"
    logger -t stray-init-cleanup "removed dangling rc.d link: $(basename $l)"
done

exit 0
PBFIX_EOF
    chmod 0755 "${PBFIX}"
    echo "[diy-part2] 99-pushbot-and-stray-cleanup 已生成: ${PBFIX}"
else
    echo "[diy-part2] WARNING: ${REPO_ROOT}/files/etc/uci-defaults 不存在, 跳过"
fi
echo "[diy-part2] === PushBot/清理段完成 ==="

#=====================================================================================
# 迅雷快鸟 (xlnetacc) 首启预置加速方向   [added 2026-10-08]
#
# 实测: 设备上 xlnetacc.general.enabled=1 但进程为空, 原因是 init 脚本第 23 行:
#   ( [ $enabled -eq 0 ] || [ $down_acc -eq 0 -a $up_acc -eq 0 ] \
#     || [ -z "$username" -o -z "$password" -o -z "$network" ] ) && return 2
# down_acc / up_acc 两项都未设置 (config_get_bool 默认 0)
#   => [ 0 -eq 0 -a 0 -eq 0 ] 为真 => return 2 拒绝启动。
#
# 该插件无任何开机自启联动, 且报错只体现在退出码上 —— LuCI 里看不出原因。
#
# 预置: 只补 down_acc=1 (下载加速是最常用方向, 上行一般用不到)。
#   account / password 属用户私有凭据, 【不预置】, 必须由用户在 LuCI 里自行填写。
#   network 若为空则补 'wan'。
#
# 实测依据: 该脚本 /usr/bin/xlnetacc.sh 依赖 uci 的 account/password 做鉴权
#   (脚本内 json_add_string passWord "$password"), 无凭据无法工作。
#
# 回滚: 删除本段 + files/etc/uci-defaults/99-xlnetacc-direction
#=====================================================================================
echo "[diy-part2] === 迅雷快鸟 首启预置加速方向 ==="
XLFIX="${REPO_ROOT}/files/etc/uci-defaults/99-xlnetacc-direction"
if [ -d "${REPO_ROOT}/files/etc/uci-defaults" ]; then
    cat > "${XLFIX}" <<'XLFIX_EOF'
#!/bin/sh
# xlnetacc 首启预置: 只补加速方向与接口, 不碰用户凭据  (幂等)
if [ -f /etc/config/xlnetacc ] || uci -q show xlnetacc >/dev/null 2>&1; then
    uci -q get xlnetacc.general >/dev/null 2>&1 || uci -q add xlnetacc general

    # 加速方向: 两项都空时才补 down_acc=1
    d=$(uci -q get xlnetacc.general.down_acc)
    u=$(uci -q get xlnetacc.general.up_acc)
    if [ -z "$d" ] && [ -z "$u" ]; then
        uci -q set xlnetacc.general.down_acc='1'
        logger -t xlnetacc-init "preset down_acc=1 (下行加速)"
    fi

    # 网络接口
    [ -z "$(uci -q get xlnetacc.general.network)" ] && uci -q set xlnetacc.general.network='wan'

    uci -q commit xlnetacc
fi
exit 0
XLFIX_EOF
    chmod 0755 "${XLFIX}"
    echo "[diy-part2] 99-xlnetacc-direction 已生成"
else
    echo "[diy-part2] WARNING: uci-defaults 目录不存在, 跳过"
fi
echo "[diy-part2] === 迅雷快鸟 段完成 ==="

#=====================================================================================
# Docker 防火墙 zone 修复 —— 修「容器端口映射从外部访问不了」   [added 2026-10-09]
#
# 【现象】容器跑起来了、`docker ps` 正常、宿主机 curl 127.0.0.1:81 返回 200,
#         但从局域网其它机器访问 http://192.168.100.1:81 连不上。
#
# 【真机定位过程】(192.168.100.1, OpenWrt 24.10.5 / firewall4 + nftables)
#   1. 排除设备整体被拦:  设备监听 0.0.0.0:9999 (python http.server)
#                        -> 外部访问成功 3/3
#   2. 排除网段不通:      SSH 22 外部可达
#   3. 精确锁定:          docker 映射的 81/8080/8443 外部全不可达 (0/3)
#   4. 容器自身健康:      curl http://172.31.0.2:81 (docker0 内) -> 200
#   5. DNAT 规则存在:     iptables-legacy nat DOCKER 链有
#                          DNAT tcp dpt:81 to:172.31.0.2:81
#   6. conntrack 决定性证据: 表里【只有设备自己发起的连接】
#                          src=192.168.100.1 ... dport=81 ... packets=0
#                          没有一条来自外部客户端 => 外部 SYN 从未被 DNAT/转发
#
# 【根因】firewall4 的 forward 链 policy drop, 而规则里没有 br-lan -> docker0 的通路:
#     forward_lan    -> accept_to_wan / accept_to_vpn / accept_to_lan
#     forward_docker -> accept_to_docker        (只管 docker0 作为入口)
#   而 Docker 的 DNAT(dport 81 -> 172.31.0.2:81) 恰好走 br-lan -> docker0 这条路径,
#   于是被 forward 链丢弃。
#
#   深一层: firewall.docker.network='docker' 引用了一个【不存在的】network.docker,
#   所以 firewall4 生成不出 accept_to_docker 转发规则。此外 /etc/config/network 里
#   也没有 Docker 网桥设备定义 (dockerd 的 uciadd 是手工命令, 不会自动跑)。
#
# 【修复】(已在真机验证, 修后 81/8080/8443 外部 3/3 可达, 页面 title 正常)
#   ① 若 network.docker0 缺失则补一个 bridge 设备定义
#   ② 确保 firewall zone 'docker' 存在 (input/output/forward ACCEPT)
#   ③ 它的 network 列表含 'docker'
#   ④ 补 forwarding: lan -> docker
#   ⑤ fw4 reload
#
# 为什么参考机 .60 正常: 它的 firewall.docker zone 是配全的, 所以同样跑
# nginx-proxy-manager, .60 能访问而本固件不能。
#
# 回滚: 删除本段 + files/etc/uci-defaults/99-docker-firewall-zone
#=====================================================================================
echo "[diy-part2] === Docker 防火墙 zone 修复 ==="
DFW="${REPO_ROOT}/files/etc/uci-defaults/99-docker-firewall-zone"
if [ -d "${REPO_ROOT}/files/etc/uci-defaults" ]; then
    cat > "${DFW}" <<'DFW_EOF'
#!/bin/sh
#======================================================================================
# Docker 防火墙 zone 修复 (first boot, 幂等, 非破坏)
#   [generated by diy-part2.sh]  详见 diy-part2.sh 中本段注释
#
# 目的: 让「br-lan -> docker0」的端口映射转发被 firewall4 放行,
#       否则容器端口映射从局域网外部无法访问 (宿主机 127.0.0.1 却是通的)。
#======================================================================================

CHANGED=0

# ---- ① network: 注册 docker0 网桥设备 ----
if ! uci -q get network.docker0 >/dev/null 2>&1; then
    # 先看是否已有同名 name=docker0 的 device
    HAVE_DEV=0
    uci -q show network | grep -q "\.name='docker0'" && HAVE_DEV=1
    if [ "${HAVE_DEV}" = "0" ]; then
        uci -q add network device >/dev/null 2>&1
        uci -q rename network.@device[-1]='docker0' 2>/dev/null
        uci -q set network.docker0.name='docker0'
        uci -q set network.docker0.type='bridge'
        uci -q set network.docker0.bridge_empty='1' 2>/dev/null
        uci -q commit network
        logger -t docker-fwzone "registered network.docker0 (bridge device)"
        CHANGED=1
    fi
fi

# ---- ② firewall zone 'docker' ----
if ! uci -q get firewall.docker >/dev/null 2>&1; then
    uci -q add firewall zone >/dev/null 2>&1
    uci -q rename firewall.@zone[-1]='docker'
    logger -t docker-fwzone "created firewall zone 'docker'"
    CHANGED=1
fi
uci -q set firewall.docker.name='docker'
uci -q set firewall.docker.input='ACCEPT'
uci -q set firewall.docker.output='ACCEPT'
uci -q set firewall.docker.forward='ACCEPT'

# ---- ③ zone 的 network 列表必须含 'docker' ----
if ! uci -q get firewall.docker.network 2>/dev/null | grep -qw 'docker'; then
    uci -q add_list firewall.docker.network='docker'
    logger -t docker-fwzone "added 'docker' to firewall.docker.network"
    CHANGED=1
fi

# ---- ④ forwarding: lan -> docker (这是修好外部访问的关键一条) ----
FW_HAVE=0
uci -q show firewall | grep -q "forwarding\[[0-9]*\]\.dest='docker'" && FW_HAVE=1
if [ "${FW_HAVE}" = "0" ]; then
    uci -q add firewall forwarding >/dev/null 2>&1
    uci -q set firewall.@forwarding[-1].src='lan'
    uci -q set firewall.@forwarding[-1].dest='docker'
    logger -t docker-fwzone "added forwarding lan->docker (fixes container port access)"
    CHANGED=1
fi

uci -q commit firewall

# ---- ⑤ 应用 ----
if [ "${CHANGED}" = "1" ]; then
    if [ -x /etc/init.d/firewall ]; then
        /etc/init.d/firewall reload >/dev/null 2>&1 || fw4 reload >/dev/null 2>&1
    fi
    logger -t docker-fwzone "firewall reloaded"
fi

exit 0
DFW_EOF
    chmod 0755 "${DFW}"
    echo "[diy-part2] 99-docker-firewall-zone 已生成: ${DFW}"
else
    echo "[diy-part2] WARNING: ${REPO_ROOT}/files/etc/uci-defaults 不存在, 跳过"
fi
echo "[diy-part2] === Docker 防火墙 zone 段完成 ==="
