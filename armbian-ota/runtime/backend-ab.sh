#!/bin/bash

AB_OTA_ROOTFS_TAR="rootfs.tar.gz"
AB_OTA_BOOT_TAR="boot.tar.gz"
AB_OTA_ROOTFS_SHA="rootfs.sha256"
AB_OTA_BOOT_SHA="boot.sha256"

BOOT_A_LABEL="armbi_boota"
BOOT_B_LABEL="armbi_bootb"
ROOT_A_LABEL="armbi_roota"
ROOT_B_LABEL="armbi_rootb"

ab_get_part_by_label() {
    blkid -t LABEL="$1" -o device 2>/dev/null | head -n1
}

ab_get_uuid_by_label() {
    blkid -t LABEL="$1" -o value -s UUID 2>/dev/null | head -n1
}

ab_get_current_slot() {
    local root_dev root_uuid root_a_uuid root_b_uuid
    root_dev=""

    if findmnt -n /media/root-ro >/dev/null 2>&1; then
        root_dev="$(findmnt -n -o SOURCE /media/root-ro)"
    fi

    if [ -z "${root_dev}" ]; then
        root_dev="$(findmnt -n -o SOURCE /)"
    fi

    if [ -z "${root_dev}" ]; then
        root_dev="$(df / | awk 'NR==2 {print $1}')"
    fi

    if [ -n "${root_dev}" ]; then
        root_uuid="$(blkid -o value -s UUID "${root_dev}" 2>/dev/null)"
        root_a_uuid="$(ab_get_uuid_by_label "${ROOT_A_LABEL}")"
        root_b_uuid="$(ab_get_uuid_by_label "${ROOT_B_LABEL}")"

        if [ -n "${root_uuid}" ] && [ "${root_uuid}" = "${root_a_uuid}" ]; then
            echo "a"
            return 0
        fi

        if [ -n "${root_uuid}" ] && [ "${root_uuid}" = "${root_b_uuid}" ]; then
            echo "b"
            return 0
        fi
    fi

    ab_uboot_get_env "boot_slot" || echo "a"
}

ab_get_target_slot() {
    if [ "$(ab_get_current_slot)" = "a" ]; then
        echo "b"
    else
        echo "a"
    fi
}

ab_get_slot_boot_label() {
    if [ "$1" = "a" ]; then
        echo "${BOOT_A_LABEL}"
    else
        echo "${BOOT_B_LABEL}"
    fi
}

ab_get_slot_root_label() {
    if [ "$1" = "a" ]; then
        echo "${ROOT_A_LABEL}"
    else
        echo "${ROOT_B_LABEL}"
    fi
}

ab_uboot_get_env() {
    fw_printenv -n "$1" 2>/dev/null || echo ""
}

ab_uboot_set_env() {
    local key="$1"
    local value="$2"
    log_info "Setting u-boot env: ${key}=${value}"
    fw_setenv "${key}" "${value}" || return 1
    [ "$(fw_printenv -n "${key}" 2>/dev/null || true)" = "${value}" ]
}

ab_get_retry_max() {
    local retry_max
    retry_max="$(ab_uboot_get_env slot_retry_max)"
    [ -n "${retry_max}" ] || retry_max="3"
    echo "${retry_max}"
}

ab_require_tools() {
    ensure_root
    init_logging
    ensure_command fw_printenv fw_setenv blkid mount umount tar findmnt sed grep awk reboot
    acquire_lock || error_exit "Cannot acquire OTA lock"
}

ab_env_slot_boot_ready() {
    local bootcmd scan preboot devtype devnum part_a part_b
    bootcmd="$(ab_uboot_get_env bootcmd)"
    scan="$(ab_uboot_get_env scan_dev_for_boot_part)"
    preboot="$(ab_uboot_get_env ab_preboot)"
    devtype="$(ab_uboot_get_env ab_boot_devtype)"
    devnum="$(ab_uboot_get_env ab_boot_devnum)"
    part_a="$(ab_uboot_get_env distro_bootpart_a)"
    part_b="$(ab_uboot_get_env distro_bootpart_b)"

    [ -n "${devtype}" ] || return 1
    [ -n "${devnum}" ] || return 1
    [ -n "${part_a}" ] || return 1
    [ -n "${part_b}" ] || return 1
    echo "${preboot}" | grep -q "slot_retry_left" || return 1
    echo "${preboot}" | grep -q "ota_in_progress" || return 1
    echo "${scan}" | grep -q "ab_boot_devtype" || return 1
    echo "${scan}" | grep -q "boot_slot" || return 1
    echo "${bootcmd}" | grep -q "run ab_preboot" || return 1
    echo "${bootcmd}" | grep -q "run distro_bootcmd" || return 1
    return 0
}

ab_ensure_slot_boot_env() {
    local init_script
    init_script="/usr/lib/armbian/armbian-ota-init-uboot"

    if ab_env_slot_boot_ready; then
        return 0
    fi

    [ -x "${init_script}" ] || error_exit "AB boot env is not initialized and ${init_script} is missing"
    log_warn "AB boot env is incomplete, trying to repair via ${init_script} --force"
    "${init_script}" --force || error_exit "Failed to reinitialize AB boot env"
    ab_env_slot_boot_ready || error_exit "AB boot env is still invalid after reinitialization"
}

ab_update_target_partition() {
    local temp_work="$1"
    local target_root_label="$2"
    local target_boot_label="$3"
    local target_slot target_root_dev target_boot_dev root_mnt boot_mnt
    local target_root_uuid target_boot_uuid existing_root_uuid existing_boot_uuid
    local fstab arm_env

    target_slot=""
    if [ "${target_root_label}" = "${ROOT_A_LABEL}" ]; then
        target_slot="a"
    elif [ "${target_root_label}" = "${ROOT_B_LABEL}" ]; then
        target_slot="b"
    fi

    target_root_dev="$(ab_get_part_by_label "${target_root_label}")"
    target_boot_dev="$(ab_get_part_by_label "${target_boot_label}")"
    [ -n "${target_root_dev}" ] || error_exit "Cannot find target root partition: ${target_root_label}"

    log_info "Updating slot ${target_slot}: root=${target_root_dev} boot=${target_boot_dev:-<none>}"

    root_mnt="$(mktemp -d)"
    mount -t ext4 -o rw "${target_root_dev}" "${root_mnt}" || {
        rm -rf "${root_mnt}"
        error_exit "Failed to mount target root partition"
    }

    (
        cd "${root_mnt}" || exit 1
        for f in * .[!.]* ..?*; do
            case "${f}" in
                .|..|lost+found)
                    continue
                    ;;
            esac
            rm -rf "${f}" 2>/dev/null || true
        done
    )

    tar --xattrs --acls --numeric-owner -xzf "${temp_work}/${AB_OTA_ROOTFS_TAR}" -C "${root_mnt}" || {
        umount "${root_mnt}" 2>/dev/null || true
        rm -rf "${root_mnt}"
        error_exit "Failed to extract rootfs payload"
    }

    if [ -n "${target_boot_dev}" ] && [ -b "${target_boot_dev}" ] && [ -f "${temp_work}/${AB_OTA_BOOT_TAR}" ]; then
        boot_mnt="$(mktemp -d)"
        if mount -t ext4 -o rw "${target_boot_dev}" "${boot_mnt}"; then
            (
                cd "${boot_mnt}" || exit 1
                for f in * .[!.]* ..?*; do
                    case "${f}" in
                        .|..|lost+found)
                            continue
                            ;;
                    esac
                    rm -rf "${f}" 2>/dev/null || true
                done
            )

            tar --xattrs --acls --numeric-owner -xzf "${temp_work}/${AB_OTA_BOOT_TAR}" -C "${boot_mnt}" || log_warn "Failed to extract boot payload"
            sync
            umount "${boot_mnt}" 2>/dev/null || true
        else
            log_warn "Failed to mount target boot partition, skipping boot update"
        fi
        rm -rf "${boot_mnt}"
    fi

    target_root_uuid="$(ab_get_uuid_by_label "${target_root_label}")"
    target_boot_uuid="$(ab_get_uuid_by_label "${target_boot_label}")"
    fstab="${root_mnt}/etc/fstab"

    if [ -f "${fstab}" ]; then
        cp "${fstab}" "${fstab}.ota-backup"
        existing_root_uuid="$(grep -m1 'UUID=[0-9a-f-]*[[:space:]]*[[:space:]]*/[[:space:]]' "${fstab}" | sed -n 's/.*UUID=\([0-9a-f-]*\).*/\1/p')"
        existing_boot_uuid="$(grep -m1 'UUID=[0-9a-f-]*[[:space:]]*[[:space:]]*/boot[[:space:]]' "${fstab}" | sed -n 's/.*UUID=\([0-9a-f-]*\).*/\1/p')"

        if [ -n "${existing_root_uuid}" ] && [ -n "${target_root_uuid}" ]; then
            sed -i "s|UUID=${existing_root_uuid}|UUID=${target_root_uuid}|g" "${fstab}"
        fi
        if [ -n "${existing_boot_uuid}" ] && [ -n "${target_boot_uuid}" ]; then
            sed -i "s|UUID=${existing_boot_uuid}|UUID=${target_boot_uuid}|g" "${fstab}"
        fi

        sed -i "s|LABEL=armbi_roota|LABEL=${target_root_label}|g" "${fstab}"
        sed -i "s|LABEL=armbi_rootb|LABEL=${target_root_label}|g" "${fstab}"
        sed -i "s|LABEL=armbi_boota|LABEL=${target_boot_label}|g" "${fstab}"
        sed -i "s|LABEL=armbi_bootb|LABEL=${target_boot_label}|g" "${fstab}"
    fi

    arm_env=""
    if [ -n "${target_boot_dev}" ] && [ -b "${target_boot_dev}" ]; then
        boot_mnt="$(mktemp -d)"
        if mount -t ext4 -o rw "${target_boot_dev}" "${boot_mnt}"; then
            arm_env="${boot_mnt}/armbianEnv.txt"
            if [ -f "${arm_env}" ] && [ -n "${target_root_uuid}" ]; then
                if grep -q '^rootdev=' "${arm_env}"; then
                    sed -i "s|^rootdev=UUID=.*$|rootdev=UUID=${target_root_uuid}|" "${arm_env}"
                    sed -i "s|^rootdev=PARTUUID=.*$|rootdev=UUID=${target_root_uuid}|" "${arm_env}"
                else
                    printf '\nrootdev=UUID=%s\n' "${target_root_uuid}" >> "${arm_env}"
                fi
            fi
            umount "${boot_mnt}" 2>/dev/null || true
        fi
        rm -rf "${boot_mnt}"
    fi

    if [ -z "${arm_env}" ] && [ -f "${root_mnt}/boot/armbianEnv.txt" ] && [ -n "${target_root_uuid}" ]; then
        arm_env="${root_mnt}/boot/armbianEnv.txt"
        if grep -q '^rootdev=' "${arm_env}"; then
            sed -i "s|^rootdev=UUID=.*$|rootdev=UUID=${target_root_uuid}|" "${arm_env}"
            sed -i "s|^rootdev=PARTUUID=.*$|rootdev=UUID=${target_root_uuid}|" "${arm_env}"
        else
            printf '\nrootdev=UUID=%s\n' "${target_root_uuid}" >> "${arm_env}"
        fi
    fi

    sync
    umount "${root_mnt}" 2>/dev/null || log_warn "Failed to unmount target root partition"
    rm -rf "${root_mnt}"
}

ab_start_ota() {
    local package_path="$1"
    local current_slot target_slot target_root_label target_boot_label temp_work

    [ -n "${package_path}" ] || error_exit "Usage: armbian-ota start --mode=ab <ota-package.tar.gz>"
    [ -f "${package_path}" ] || error_exit "OTA package not found: ${package_path}"
    ab_require_tools
    assert_package_mode_matches "${package_path}" "ab"
    ab_ensure_slot_boot_env

    current_slot="$(ab_get_current_slot)"
    target_slot="$(ab_get_target_slot)"
    target_root_label="$(ab_get_slot_root_label "${target_slot}")"
    target_boot_label="$(ab_get_slot_boot_label "${target_slot}")"

    if [ "$(ab_uboot_get_env ota_in_progress)" = "1" ]; then
        error_exit "Another AB OTA boot verification is still in progress"
    fi

    temp_work="$(mktemp -d)"
    extract_ota_package "${package_path}" "${temp_work}"
    verify_sha256 "${temp_work}/${AB_OTA_ROOTFS_TAR}" "${temp_work}/${AB_OTA_ROOTFS_SHA}" "rootfs.tar.gz"
    if [ -f "${temp_work}/${AB_OTA_BOOT_TAR}" ] && [ -f "${temp_work}/${AB_OTA_BOOT_SHA}" ]; then
        verify_sha256 "${temp_work}/${AB_OTA_BOOT_TAR}" "${temp_work}/${AB_OTA_BOOT_SHA}" "boot.tar.gz"
    fi

    ab_update_target_partition "${temp_work}" "${target_root_label}" "${target_boot_label}"
    rm -rf "${temp_work}"

    state_init
    state_mark_mode "ab"
    state_mark_status "ready_to_boot"
    state_set "PACKAGE_PATH" "$(basename "${package_path}")"
    state_set "CURRENT_SLOT" "${current_slot}"
    state_set "TARGET_SLOT" "${target_slot}"
    state_set "START_TIME" "$(date -Iseconds)"
    state_set "COMPLETE_TIME" ""

    ab_uboot_set_env "ota_in_progress" "1" || error_exit "Failed to set ota_in_progress"
    ab_uboot_set_env "boot_slot" "${target_slot}" || error_exit "Failed to switch boot_slot"
    ab_uboot_set_env "try_count" "0" || log_warn "Failed to reset try_count"
    ab_uboot_set_env "slot_retry_max" "$(ab_get_retry_max)" || log_warn "Failed to set slot_retry_max"
    ab_uboot_set_env "slot_retry_left" "$(ab_get_retry_max)" || error_exit "Failed to set slot_retry_left"

    log_info "AB OTA staged successfully. Current slot=${current_slot}, target slot=${target_slot}"
    log_info "Reboot to boot the new slot"
}

ab_mark_success() {
    local current_slot
    ab_require_tools

    if [ "$(state_get OTA_MODE)" != "ab" ] && [ "$(ab_uboot_get_env ota_in_progress)" != "1" ]; then
        log_info "No A/B OTA in progress, nothing to mark"
        return 0
    fi

    current_slot="$(ab_get_current_slot)"
    ab_uboot_set_env "boot_success" "${current_slot}" || log_error "Failed to set boot_success"
    ab_uboot_set_env "ota_in_progress" "0" || log_error "Failed to clear ota_in_progress"
    ab_uboot_set_env "try_count" "0" || log_warn "Failed to reset try_count"
    ab_uboot_set_env "slot_retry_left" "$(ab_get_retry_max)" || log_warn "Failed to reset slot_retry_left"

    state_mark_mode "ab"
    state_mark_status "success"
    state_set "CURRENT_SLOT" "${current_slot}"
    state_set "TARGET_SLOT" ""
    state_set "COMPLETE_TIME" "$(date -Iseconds)"

    log_info "AB OTA marked successful on slot ${current_slot}"
}

ab_rollback() {
    local last_success try_count max_tries
    ab_require_tools

    if [ "$(ab_uboot_get_env ota_in_progress)" != "1" ]; then
        log_info "No A/B OTA in progress, nothing to rollback"
        return 0
    fi

    last_success="$(ab_uboot_get_env boot_success)"
    [ -n "${last_success}" ] || last_success="a"

    try_count="$(ab_uboot_get_env try_count)"
    try_count="${try_count:-0}"
    try_count=$((try_count + 1))
    max_tries="$(state_get MAX_TRIES)"
    max_tries="${max_tries:-3}"

    if [ "${try_count}" -ge "${max_tries}" ]; then
        state_mark_mode "ab"
        state_mark_status "failed"
        state_set "COMPLETE_TIME" "$(date -Iseconds)"
        ab_uboot_set_env "ota_in_progress" "0" || true
        error_exit "Maximum rollback retry count reached"
    fi

    ab_uboot_set_env "boot_slot" "${last_success}" || log_error "Failed to restore boot_slot"
    ab_uboot_set_env "ota_in_progress" "0" || log_error "Failed to clear ota_in_progress"
    ab_uboot_set_env "try_count" "${try_count}" || log_error "Failed to update try_count"
    ab_uboot_set_env "slot_retry_left" "$(ab_get_retry_max)" || log_warn "Failed to reset slot_retry_left"

    state_mark_mode "ab"
    state_mark_status "rollback"
    state_set "CURRENT_SLOT" "${last_success}"
    state_set "TARGET_SLOT" ""
    state_set "COMPLETE_TIME" "$(date -Iseconds)"

    log_info "Rollback configured, rebooting back to slot ${last_success}"
    sync
    reboot
}

ab_status() {
    local current_slot ota_in_progress
    current_slot="$(ab_get_current_slot)"
    ota_in_progress="$(ab_uboot_get_env ota_in_progress)"

    echo "=== Armbian OTA Status (A/B) ==="
    echo "Mode: ab"
    echo "Status: $(state_get STATUS)"
    echo "Current slot: ${current_slot}"
    echo "Target slot: $(state_get TARGET_SLOT)"
    echo ""
    echo "U-Boot Environment:"
    echo "  boot_slot: $(ab_uboot_get_env boot_slot)"
    echo "  boot_success: $(ab_uboot_get_env boot_success)"
    echo "  ota_in_progress: ${ota_in_progress}"
    echo "  try_count: $(ab_uboot_get_env try_count)"
    echo "  slot_retry_max: $(ab_get_retry_max)"
    echo "  slot_retry_left: $(ab_uboot_get_env slot_retry_left)"
    echo ""
    echo "Partitions:"
    for label in "${BOOT_A_LABEL}" "${BOOT_B_LABEL}" "${ROOT_A_LABEL}" "${ROOT_B_LABEL}"; do
        local dev uuid mark slot
        dev="$(ab_get_part_by_label "${label}")"
        uuid="$(ab_get_uuid_by_label "${label}")"
        mark=""
        slot=""
        case "${label}" in
            "${BOOT_A_LABEL}"|"${ROOT_A_LABEL}") slot="a" ;;
            "${BOOT_B_LABEL}"|"${ROOT_B_LABEL}") slot="b" ;;
        esac
        if [ "${slot}" = "${current_slot}" ]; then
            mark=" [BOOTING]"
        fi
        echo "  ${label}: ${dev:-NOT FOUND} ${uuid:+(UUID: ${uuid})}${mark}"
    done
}
