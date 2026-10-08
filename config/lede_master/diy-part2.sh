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
