if [[ "${CRYPTROOT_ENABLE}" == "yes" && "${RK_AUTO_DECRYP}" == "yes" ]]; then
	display_alert "Cryptroot" "Enable RK to automatically unlock encrypted containers" "info"
	export CRYPTROOT_SSH_UNLOCK=no
	export RK_SECURE_UBOOT_ENABLE=yes
	enable_extension "seeed_armbian_extension/rk_secure-disk-encryption/rk-auto-decryption-disk"
fi

if [[ "${RK_SECURE_UBOOT_ENABLE}" == "yes" ]]; then
	display_alert "Secure U-Boot" "Enable Secure Boot Extensions" "info"
	enable_extension "seeed_armbian_extension/rk_secure-disk-encryption/rk-secure-boot"
fi

if [[ "${OTA_ENABLE}" == "yes" ]]; then
	display_alert "OTA_ENABLE" "Enable OTA extension ota-support" "info"
	enable_extension "seeed_armbian_extension/armbian-ota/ota-support"
fi
