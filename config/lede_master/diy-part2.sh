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
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_luci-app-ssr-plus=y
CONFIG_PACKAGE_luci-app-wechatpush=y
CONFIG_PACKAGE_luci-app-timecontrol=y
CONFIG_PACKAGE_luci-app-pushbot=y
CONFIG_PACKAGE_luci-app-unblockmusic=y
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_luci-app-smartdns=y
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
CONFIG_PACKAGE_luci-app-mjpg-streamer=y
CONFIG_PACKAGE_luci-app-rclone=y
CONFIG_PACKAGE_luci-app-aria2=y
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
CONFIG_PACKAGE_luci-app-softethervpn=y
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
echo "[diy-part2] === 可道云: 注入 kodbox ${KODBOX_VER} ==="
if curl -fsSL -o /tmp/kodbox.zip "${KODBOX_URL}"; then
    rm -rf /tmp/kodx && mkdir -p /tmp/kodx "$KODBOX_DST"
    unzip -q -o /tmp/kodbox.zip -d /tmp/kodx
    cp -rf "/tmp/kodx/kodbox-${KODBOX_VER}/." "$KODBOX_DST/"
    rm -rf /tmp/kodbox.zip /tmp/kodx
    echo "[diy-part2] kodbox injected: $(du -sh "$KODBOX_DST" | cut -f1)"
else
    echo "[diy-part2] WARNING: kodbox 下载失败, 跳过注入 (固件仍可用, 需手动更新)"
fi

# ---- 3. 补丁 api.lua: to_check() 直接返回 GitHub 下载地址, 修复"手动更新"按钮 ----
KOD_API="feeds/small/luci-app-kodexplorer/luasrc/model/cbi/kodexplorer/api.lua"
if [ -f "$KOD_API" ]; then
    cp -f "$KOD_API" "${KOD_API}.orig"
    sed -i "s#^function to_check()#function to_check()\n    return { code = 0, data = { server = { version = \"${KODBOX_VER}\", link = \"${KODBOX_URL}\" } } }#" "$KOD_API"
    grep -q "${KODBOX_URL}" "$KOD_API" \
        && echo "[diy-part2] api.lua patched OK" \
        || echo "[diy-part2] WARNING: api.lua patch failed (函数签名可能已变)"
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
