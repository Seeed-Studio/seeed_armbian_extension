function pre_umount_final_image__050_set_armbianenv_verbosity_for_cryptroot() {
	# Encryption builds should keep initramfs/kernel logs verbose for early-boot troubleshooting.
	if [[ "${CRYPTROOT_ENABLE}" != "yes" ]]; then
		return 0
	fi

	local root_dir="${MOUNT}"
	[[ -d "${root_dir}" ]] || return 0

	local candidates=(
		"${root_dir}/boot/armbianEnv.txt"
		"${root_dir}/armbianEnv.txt"
	)

	local env_file updated=0
	for env_file in "${candidates[@]}"; do
		[[ -f "${env_file}" ]] || continue
		if grep -q '^verbosity=' "${env_file}" 2>/dev/null; then
			sed -i 's/^verbosity=.*/verbosity=7/' "${env_file}" || true
		else
			printf '\nverbosity=7\n' >> "${env_file}"
		fi
		display_alert "Cryptroot" "Set verbosity=7 in ${env_file}" "info"
		updated=1
	done

	if [[ "${updated}" -eq 0 ]]; then
		mkdir -p "${root_dir}/boot" 2>/dev/null || true
		printf 'verbosity=7\n' > "${root_dir}/boot/armbianEnv.txt"
		display_alert "Cryptroot" "Created ${root_dir}/boot/armbianEnv.txt with verbosity=7" "info"
	fi
}
