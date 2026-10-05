#!/bin/bash
#================================================================================================
#
# OpenWrt-X96MaxPlus-N1 : Build OpenWrt rootfs using the official Image Builder
#
# Copyright (C) 2021~ https://github.com/unifreq/openwrt_packit
# Copyright (C) 2021~ https://github.com/ophub/amlogic-s9xxx-openwrt
# Copyright (C) 2021~ https://downloads.openwrt.org/releases
#
# Command: ./config/imagebuilder/imagebuilder.sh <source:branch>
#          ./config/imagebuilder/imagebuilder.sh openwrt:25.12.5
#
# Phase 1: minimal bootable firmware (LuCI + SSH + network + USB + storage + basic tools)
# ================================================================================================

make_path="${PWD}"
openwrt_dir="imagebuilder"
imagebuilder_path="${make_path}/${openwrt_dir}"
custom_files_path="${make_path}/config/imagebuilder/files"
custom_config_file="${make_path}/config/imagebuilder/config"
custom_packages_path="${make_path}/config/imagebuilder/packages"
output_path="${make_path}/output"
tmp_path="${imagebuilder_path}/tmp"
unpack_path="${tmp_path}/unpacked_rootfs"

STEPS="[\033[95m STEPS \033[0m]"
INFO="[\033[94m INFO \033[0m]"
SUCCESS="[\033[92m SUCCESS \033[0m]"
WARNING="[\033[93m WARNING \033[0m]"
ERROR="[\033[91m ERROR \033[0m]"

error_msg() {
    echo -e "${ERROR} ${1}"
    exit 1
}

download_imagebuilder() {
    cd ${make_path}
    echo -e "${STEPS} Downloading OpenWrt ImageBuilder..."

    if [[ "${op_sourse}" == "immortalwrt" ]]; then
        download_url="downloads.immortalwrt.org"
    else
        download_url="downloads.openwrt.org"
    fi
    download_file="https://${download_url}/releases/${op_branch}/targets/armsr/armv8/${op_sourse}-imagebuilder-${op_branch}-armsr-armv8.Linux-x86_64.tar.zst"
    curl -fsSOL ${download_file}
    [[ "${?}" -eq "0" ]] || error_msg "Failed to download: [ ${download_file} ]"

    tar -I zstd -xvf *-imagebuilder-*.tar.zst -C . && sync && rm -f *-imagebuilder-*.tar.zst
    mv -f *-imagebuilder-* ${openwrt_dir}

    sync && sleep 3
    echo -e "${INFO} [ ${make_path} ] directory contents: \n$(ls -lh . 2>/dev/null)"
}

adjust_settings() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Adjusting ImageBuilder .config settings..."

    if [[ -s ".config" ]]; then
        sed -i "s|CONFIG_TARGET_ROOTFS_CPIOGZ=.*|# CONFIG_TARGET_ROOTFS_CPIOGZ is not set|g" .config
        # Keep EXT4FS enabled: Amlogic boxes boot from ext4 rootfs
        sed -i "s|CONFIG_TARGET_ROOTFS_EXT4FS=.*|CONFIG_TARGET_ROOTFS_EXT4FS=y|g" .config
        sed -i "s|CONFIG_TARGET_ROOTFS_SQUASHFS=.*|# CONFIG_TARGET_ROOTFS_SQUASHFS is not set|g" .config
        sed -i "s|CONFIG_TARGET_IMAGES_GZIP=.*|# CONFIG_TARGET_IMAGES_GZIP is not set|g" .config
        # Bigger rootfs to fit packages (8GB boxes / SD cards)
        sed -i "s|CONFIG_TARGET_ROOTFS_PARTSIZE=.*|CONFIG_TARGET_ROOTFS_PARTSIZE=1024|g" .config
    else
        echo -e "${INFO} [ ${imagebuilder_path} ] directory contents: \n$(ls -lh . 2>/dev/null)"
        error_msg "No .config file found in [ ${download_file} ]."
    fi

    sync && sleep 3
}

custom_packages() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Adding custom packages..."

    [[ -d "packages" ]] || mkdir packages
    cd packages

    # luci-app-amlogic : required for installing to eMMC on Amlogic boxes
    amlogic_api="https://api.github.com/repos/ophub/luci-app-amlogic/releases"
    amlogic_plugin_latest_version="$(curl -s ${amlogic_api} | grep -oP '(?<="tag_name": ")[^"]+' | grep "\-js$" | sort -Vur | head -n1)"
    [[ -z "${amlogic_plugin_latest_version}" ]] && amlogic_plugin_latest_version="$(curl -s ${amlogic_api} | grep -oP '(?<="tag_name": ")[^"]+' | sort -Vur | head -n1)"
    amlogic_plugin_list=($(curl -s ${amlogic_api} | grep "browser_download_url" | grep -oE "https.*/${amlogic_plugin_latest_version}/.*\.(ipk|apk)"))

    for plugin_url in "${amlogic_plugin_list[@]}"; do
        curl -fsSOJL "${plugin_url}"
        [[ "${?}" -eq "0" ]] && echo -e "${INFO} The [ ${plugin_url} ] is downloaded successfully."
    done

    # Extra local .ipk/.apk placed under config/imagebuilder/packages
    if [[ -d "${custom_packages_path}" ]] && [[ -n "$(ls -A ${custom_packages_path} 2>/dev/null)" ]]; then
        cp -f ${custom_packages_path}/*.ipk ${custom_packages_path}/*.apk . 2>/dev/null || true
    fi

    # Keep only the format matching the ImageBuilder type
    if grep -q "CONFIG_USE_APK=y" ../.config; then
        echo -e "${INFO} APK-based ImageBuilder detected. Removing .ipk files..."
        rm -f *.ipk
        for file in *.apk; do
            [[ -e "${file}" ]] || continue
            new_file=$(echo "${file}" | sed -E 's/\.([a-f0-9]{7}\.apk)/~\1/')
            if [[ "${file}" != "${new_file}" ]]; then
                mv -f "${file}" "${new_file}" || true
                echo -e "${INFO} Renamed: ${file} -> ${new_file}"
            fi
        done
    else
        echo -e "${INFO} OPKG-based ImageBuilder detected. Removing .apk files..."
        rm -f *.apk
    fi

    sync && sleep 3
    echo -e "${INFO} [ packages ] directory contents: \n$(ls -lh . 2>/dev/null)"
}

custom_config() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Loading custom package configuration..."

    config_list=""
    if [[ -s "${custom_config_file}" ]]; then
        config_list="$(sed -n 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/p' "${custom_config_file}" | tr '\n' ' ')"
        echo -e "${INFO} Custom package list: \n$(echo "${config_list}" | tr ' ' '\n')"
    else
        echo -e "${INFO} No custom configuration file found, skipped."
    fi
}

custom_files() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Adding custom files..."

    if [[ -d "${custom_files_path}" ]]; then
        [[ -d "files" ]] || mkdir -p files
        cp -rf ${custom_files_path}/* files
        sync && sleep 3
        echo -e "${INFO} [ files ] directory contents: \n$(find files -type f 2>/dev/null)"
    else
        echo -e "${INFO} No custom files added, skipped."
    fi
}

rebuild_firmware() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Building OpenWrt firmware with Image Builder..."

    # ---- Phase 1 core packages ----
    # LuCI + SSH + network + USB + storage + basic tools + Amlogic app
    my_packages="\
        acpid attr base-files bash bc blkid block-mount blockd bsdtar btrfs-progs busybox bzip2 \
        cgi-io chattr comgt comgt-ncm containerd coremark coreutils coreutils-base64 coreutils-nohup \
        coreutils-truncate containerd curl docker docker-compose dockerd runc dosfstools dumpe2fs e2freefrag e2fsprogs \
        exfat-mkfs f2fs-tools f2fsck fdisk gawk getopt git gzip hostapd-common iconv iw iwinfo jq \
        jshn kmod-brcmfmac kmod-brcmutil kmod-cfg80211 kmod-mac80211 libjson-script liblucihttp \
        liblucihttp-lua losetup lsattr lsblk lscpu mkf2fs mount-utils openssl-util parted \
        perl-http-date perlbase-file perlbase-getopt perlbase-time perlbase-unicode perlbase-utf8 \
        pigz ppp ppp-mod-pppoe pv rename resize2fs runc tar tini ttyd tune2fs \
        uclient-fetch uhttpd uhttpd-mod-ubus unzip uqmi usb-modeswitch uuidgen wget-ssl whereis \
        which wpad-basic wwan xfs-fsck xfs-mkfs xz xz-utils ziptool zoneinfo-asia zoneinfo-core zstd \
        \
        luci luci-base luci-compat luci-i18n-base-zh-cn luci-lib-base \
        luci-lib-ip luci-lib-ipkg luci-lib-jsonc luci-lib-nixio luci-mod-admin-full luci-mod-network \
        luci-mod-status luci-mod-system luci-proto-3g luci-proto-ipip luci-proto-ipv6 \
        luci-proto-ncm luci-proto-openconnect luci-proto-ppp luci-proto-qmi luci-proto-relay \
        \
        luci-app-amlogic luci-i18n-amlogic-zh-cn \
        \
        ${config_list} \
        "

    make image PROFILE="" PACKAGES="${my_packages}" FILES="files"

    sync && sleep 3
    echo -e "${INFO} [ ${openwrt_dir}/bin/targets/*/*/ ] directory contents: \n$(ls -lh bin/targets/*/*/ 2>/dev/null)"
    echo -e "${INFO} Firmware build completed successfully."
}

custom_settings() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Applying post-build customizations..."

    [[ -d "${tmp_path}" ]] && rm -rf "${tmp_path:?}"/* || mkdir -p "${tmp_path}"
    [[ -d "${output_path}" ]] && rm -rf "${output_path:?}"/* || mkdir -p "${output_path}"

    original_archive="$(ls -1 bin/targets/*/*/*rootfs.tar.gz 2>/dev/null | head -n 1)"

    if [[ ! -f "${original_archive}" ]]; then
        error_msg "No rootfs.tar.gz archive found in build output."
    else
        echo -e "${INFO} Found rootfs archive: ${original_archive}"
        original_filename="$(basename "${original_archive}")"

        echo -e "${INFO} Unpacking ${original_filename}..."
        mkdir -p "${unpack_path}"
        tar -xzpf "${original_archive}" -C "${unpack_path}"

        release_file="${unpack_path}/etc/openwrt_release"
        if [[ -f "${release_file}" ]]; then
            echo -e "${INFO} Updating etc/openwrt_release..."
            {
                echo "DISTRIB_SOURCEREPO='github.com/${op_sourse}/${op_sourse}'"
                echo "DISTRIB_SOURCECODE='${op_sourse}'"
                echo "DISTRIB_SOURCEBRANCH='${op_branch}'"
            } >>"${release_file}"
        else
            error_msg "${release_file} not found."
        fi

        # Force uid/gid 0 on repack (see upstream imagebuilder.sh rationale)
        echo -e "${INFO} Repacking into ${original_filename}..."
        (cd "${unpack_path}" && tar --numeric-owner --owner=0 --group=0 -czpf "${tmp_path}/${original_filename}" ./)

        mv -f "${tmp_path}/${original_filename}" "${output_path}/"
        cp -f .config "${output_path}/config" || true
    fi

    sync && sleep 3
    cd ${make_path}
    rm -rf "${imagebuilder_path}"
    echo -e "${INFO} [ ${output_path} ] directory contents: \n$(ls -lh ${output_path}/ 2>/dev/null)"
    echo -e "${INFO} Post-build customizations applied successfully."
}

# ---- main ----
echo -e "${STEPS} Welcome to OpenWrt Image Builder (X96Max+ / N1 project)."
[[ -x "${0}" ]] || error_msg "Please grant execution permission: [ chmod +x ${0} ]"
[[ -z "${1}" ]] && error_msg "Please specify the OpenWrt source and branch, e.g. [ ${0} openwrt:25.12.5 ]"
[[ "${1}" =~ ^[a-z]{3,}:[0-9]+ ]] || error_msg "Invalid parameter format. Expected <source:branch>."
op_sourse="${1%:*}"
op_branch="${1#*:}"
echo -e "${INFO} Working directory: [ ${PWD} ]"
echo -e "${INFO} Source: [ ${op_sourse} ], Branch: [ ${op_branch} ]"

download_imagebuilder
adjust_settings
custom_packages
custom_config
custom_files
rebuild_firmware
custom_settings

echo -e "${SUCCESS} OpenWrt Image Builder completed successfully."
