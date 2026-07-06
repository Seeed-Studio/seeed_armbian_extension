#!/bin/bash

function _seeed_gnome_wayland_default_enabled() {
	[[ "${BOARD}" == "recomputer-rk3588-devkit" ]] || return 1
	[[ "${BUILD_DESKTOP}" == "yes" ]] || return 1
	[[ "${DESKTOP_ENVIRONMENT}" == "gnome" ]] || return 1
	return 0
}

function _seeed_gnome_wayland_default_user() {
	local user="${SEEED_GNOME_WAYLAND_DEFAULT_USER:-${PRESET_USER_NAME:-seeed}}"

	if [[ ! "${user}" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
		display_alert "GNOME Wayland default" "Invalid default user '${user}', skipping AccountsService default" "warn"
		return 1
	fi

	printf '%s\n' "${user}"
}

function _seeed_gnome_wayland_default_root() {
	if [[ -n "${MOUNT:-}" && -d "${MOUNT}" ]]; then
		printf '%s\n' "${MOUNT}"
	else
		printf '%s\n' "${SDCARD}"
	fi
}

function _seeed_write_accountsservice_wayland_default() {
	local root_dir="$1"
	local user="$2"
	local account_dir="${root_dir}/var/lib/AccountsService/users"
	local account_file="${account_dir}/${user}"
	local account_tmp="${account_file}.tmp"

	install -d -m 0755 "${account_dir}"

	{
		printf '[User]\n'
		if [[ -f "${account_file}" ]]; then
			awk '
				$0 == "[User]" { in_user = 1; next }
				/^\[/ { if (in_user) exit }
				in_user && $0 !~ /^(Session|SessionType|XSession|SystemAccount)=/ && length($0) { print }
			' "${account_file}"
		fi
		printf 'Session=gnome-wayland\n'
		printf 'SessionType=wayland\n'
		printf 'XSession=gnome-wayland\n'
		printf 'SystemAccount=false\n'
	} > "${account_tmp}"

	chown root:root "${account_tmp}" 2>/dev/null || true
	chmod 0644 "${account_tmp}"
	mv -f "${account_tmp}" "${account_file}"
}

function _seeed_patch_firstlogin_accountsservice_wayland_default() {
	local root_dir="$1"
	local firstlogin="${root_dir}/usr/lib/armbian/armbian-firstlogin"
	local firstlogin_tmp="${firstlogin}.tmp"
	local has_accounts_session="no"

	[[ -f "${firstlogin}" ]] || return 0

	if ! grep -q '^[[:space:]]*Icon=\$ICON_DST$' "${firstlogin}"; then
		display_alert "GNOME Wayland default" "armbian-firstlogin AccountsService template not found" "warn"
		return 0
	fi

	if grep -q '^[[:space:]]*\(Session\|SessionType\|XSession\)=' "${firstlogin}"; then
		has_accounts_session="yes"
	fi

	awk -v has_accounts_session="${has_accounts_session}" '
		/^[[:space:]]*Session=/ {
			print "\tSession=gnome-wayland"
			next
		}
		/^[[:space:]]*SessionType=/ {
			print "\tSessionType=wayland"
			next
		}
		/^[[:space:]]*XSession=/ {
			print "\tXSession=gnome-wayland"
			next
		}
		/^[[:space:]]*Icon=\$ICON_DST$/ && has_accounts_session != "yes" && !inserted {
			print
			print "\tSession=gnome-wayland"
			print "\tSessionType=wayland"
			print "\tXSession=gnome-wayland"
			inserted = 1
			next
		}
		{ print }
	' "${firstlogin}" > "${firstlogin_tmp}"

	chown --reference="${firstlogin}" "${firstlogin_tmp}" 2>/dev/null || true
	chmod --reference="${firstlogin}" "${firstlogin_tmp}"
	mv -f "${firstlogin_tmp}" "${firstlogin}"
}

function _seeed_enable_gdm_wayland() {
	local root_dir="$1"
	local gdm_conf="${root_dir}/etc/gdm3/daemon.conf"

	[[ -f "${gdm_conf}" ]] || return 0

	sed -i 's/^[[:space:]]*WaylandEnable=false/#WaylandEnable=false/' "${gdm_conf}"
}

function pre_umount_final_image__seeed_gnome_wayland_default() {
	_seeed_gnome_wayland_default_enabled || return 0

	local user
	user="$(_seeed_gnome_wayland_default_user)" || return 0
	local root_dir
	root_dir="$(_seeed_gnome_wayland_default_root)"

	display_alert "GNOME Wayland default" "Defaulting ${user} to GNOME Wayland on RK3588" "info"

	_seeed_write_accountsservice_wayland_default "${root_dir}" "${user}"
	_seeed_patch_firstlogin_accountsservice_wayland_default "${root_dir}"
	_seeed_enable_gdm_wayland "${root_dir}"
}
