if [[ "${RK_SECURE_UBOOT_ENABLE}" == "yes" && "${CRYPTROOT_ENABLE}" != "yes" ]]; then
	display_alert "Secure U-Boot" "RK_SECURE_UBOOT_ENABLE requires CRYPTROOT_ENABLE=yes, forcing enable" "warn"
	export CRYPTROOT_ENABLE=yes
fi

if [[ "${CRYPTROOT_ENABLE}" == "yes" ]]; then
	cryptroot_passphrase_len="${#CRYPTROOT_PASSPHRASE}"
	if [[ "${cryptroot_passphrase_len}" -ne 64 ]]; then
		display_alert "Cryptroot" "CRYPTROOT_PASSPHRASE must be exactly 64 characters (actual: ${cryptroot_passphrase_len})" "err"
		if [[ "$(type -t exit_with_error || true)" == "function" ]]; then
			exit_with_error "Invalid CRYPTROOT_PASSPHRASE length" "expected=64 actual=${cryptroot_passphrase_len}"
		fi
		exit 1
	fi

	enable_extension "seeed_armbian_extension/rk_secure-disk-encryption/rk-cryptroot-verbosity"
fi

if [[ "${CRYPTROOT_ENABLE}" == "yes" && "${RK_AUTO_DECRYP}" == "yes" ]]; then
	display_alert "Cryptroot" "Enable RK to automatically unlock encrypted containers" "info"
	export CRYPTROOT_SSH_UNLOCK=no
	enable_extension "seeed_armbian_extension/rk_secure-disk-encryption/rk-auto-decryption-disk"
fi

if [[ "${RK_SECURE_UBOOT_ENABLE}" == "yes" || "${RK_OPTEE_BOOT_ENABLE}" == "yes" ]]; then
	if [[ "${RK_SECURE_UBOOT_ENABLE}" == "yes" ]]; then
		display_alert "Secure U-Boot" "Enable Secure Boot Extensions" "info"
	else
		display_alert "OP-TEE bootchain" "Enable rk-secure-boot extension in OP-TEE bootchain mode" "info"
	fi
	enable_extension "seeed_armbian_extension/rk_secure-disk-encryption/rk-secure-boot"
fi

if [[ "${OTA_ENABLE}" == "yes" ]]; then
	display_alert "OTA_ENABLE" "Enable OTA extension ota-support" "info"
	enable_extension "seeed_armbian_extension/armbian-ota/ota-support"
fi
