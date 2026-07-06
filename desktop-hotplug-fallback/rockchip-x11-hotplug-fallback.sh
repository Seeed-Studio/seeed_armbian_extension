#!/bin/bash

function _seeed_rockchip_x11_hotplug_fallback_enabled() {
	[[ "${BOARD}" == "recomputer-rk3588-devkit" ]] || return 1
	[[ "${BUILD_DESKTOP}" == "yes" ]] || return 1
	return 0
}

function _seeed_rockchip_x11_hotplug_fallback_root() {
	if [[ -n "${MOUNT:-}" && -d "${MOUNT}" ]]; then
		printf '%s\n' "${MOUNT}"
	else
		printf '%s\n' "${SDCARD}"
	fi
}

function pre_umount_final_image__seeed_rockchip_x11_hotplug_fallback() {
	_seeed_rockchip_x11_hotplug_fallback_enabled || return 0

	local root_dir
	root_dir="$(_seeed_rockchip_x11_hotplug_fallback_root)"
	local xorg_dir="${root_dir}/etc/X11/xorg.conf.d"
	local xorg_conf="${xorg_dir}/11-rockchip-disable-glamor.conf"

	display_alert "Rockchip X11 hotplug fallback" "Disabling glamor for Xorg modesetting fallback" "info"

	install -d -m 0755 "${xorg_dir}"
	cat > "${xorg_conf}" <<-'EOF'
	Section "OutputClass"
	    Identifier  "RockchipDRMNoGlamor"
	    MatchDriver "rockchip"
	    Driver      "modesetting"
	    Option      "AccelMethod" "none"
	    Option      "SWcursor" "true"
	EndSection
	EOF

	chown root:root "${xorg_conf}" 2>/dev/null || true
	chmod 0644 "${xorg_conf}"
}
