function prepare_root_device__240_cleanup_stale_armbian_root() {
	if [[ "${CRYPTROOT_ENABLE}" != "yes" ]]; then
		return 0
	fi

	if [[ "${OTA_ENABLE}" != "yes" && "${AB_PART_OTA}" != "yes" ]]; then
		return 0
	fi

	if [[ "${rootdevice}" != /dev/loop* ]]; then
		return 0
	fi

	if cryptsetup status armbian-root >/dev/null 2>&1 || dmsetup info armbian-root >/dev/null 2>&1; then
		display_alert "seeed-build-compat" "Cleaning stale mapper /dev/mapper/armbian-root before luksOpen" "warn"
		cryptsetup luksClose armbian-root 2>/dev/null || true
		dmsetup remove -f armbian-root 2>/dev/null || true
		udevadm settle 2>/dev/null || true
		sleep 1
	fi
}
