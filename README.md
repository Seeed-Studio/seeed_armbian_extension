# Seeed Armbian Extension (RK35xx)

Armbian board-support extensions for Seeed reComputer RK3576/RK3588 devices:

- **OTA updates** — Recovery (single system, initramfs-applied) and A/B
  (dual slot, health checks, automatic rollback)
- **Disk encryption** — LUKS rootfs with unattended unlock (security
  partition + OP-TEE)
- **Secure boot** — Rockchip signed bootchain: loader → SPL → U-Boot FIT
  (ATF + OP-TEE) → signed kernel FIT
- **Robustness extras** — SSH power-loss recovery, multi-disk boot
  anchoring, PCIe ASPM off (`extraargs=pcie_aspm=off`)

> New here? Start with the step-by-step guides under [`docs/`](docs/README.md).

## Prebuilt Images

Official Armbian images, per board:

- [reComputer RK3576 DevKit](https://armbian.com/boards/recomputer-rk3576-devkit)
- [reComputer RK3576 Module DevKit](https://armbian.com/boards/recomputer-rk3576-module-devkit)
- [reComputer RK3576 Industrial](https://armbian.com/boards/recomputer-rk3576-industrial)
- [reComputer RK3588 DevKit](https://armbian.com/boards/recomputer-rk3588-devkit)

Flashing steps: [01-getting-started.md §5](docs/01-getting-started.md#5-flash-and-boot).

## Quick Start

Builds run from an Armbian build tree: clone this extension into
`userextensions/seeed_armbian_extension`, then copy its
`scripts/build.sh` next to `compile.sh` (setup:
[01-getting-started.md](docs/01-getting-started.md);
full reference: [02-build-reference.md](docs/02-build-reference.md)):

```bash
cd <armbian-build>    # build.sh copied next to compile.sh

./build.sh recovery -b recomputer-rk3576-devkit     # Recovery OTA image
./build.sh ab -b recomputer-rk3576-devkit           # A/B OTA image

# Encrypted + signed (passphrase must be exactly 64 hex chars)
CRYPTROOT_PASSPHRASE='<64-hex-char-passphrase>' \
./build.sh recovery secure-boot --minimal -b recomputer-rk3576-devkit
```

Images land in `output/images/`, logs in `output/logs/`.

## Applying an Update on the Device

```bash
armbian-ota start <package>_OTA.tar.gz    # mode auto-detected from the package
reboot
armbian-ota status                        # check state after reboot
armbian-ota switch-slot [a|b]             # A/B firmware only
```

Details:
- [03-ota-recovery.md](docs/03-ota-recovery.md),
- [04-ota-ab.md](docs/04-ota-ab.md).

## Feature Matrix

| Feature | Key flags | Description |
|---|---|---|
| Recovery OTA | `OTA_ENABLE=yes`, `AB_PART_OTA` unset | Single-system OTA applied in initramfs after reboot |
| A/B OTA | `OTA_ENABLE=yes AB_PART_OTA=yes` | Dual-slot OTA with health checks and automatic rollback |
| LUKS root | `CRYPTROOT_ENABLE=yes` | Encrypted root filesystem (upstream Armbian flow) |
| Secure rootfs | `RK_OPTEE_BOOT_ENABLE=yes` | LUKS + OP-TEE/SSKR automatic unlock, unsigned bootchain |
| Secure boot | `RK_SECURE_UBOOT_ENABLE=yes` | Secure rootfs plus Rockchip signed boot flow |

OTA flags combine freely with the encryption tiers (plain / secure-rootfs /
secure-boot).

## Documentation

- [01-getting-started.md](docs/01-getting-started.md) - setup and first build
- [02-build-reference.md](docs/02-build-reference.md) - every profile and variable
- [03-ota-recovery.md](docs/03-ota-recovery.md) - Recovery OTA end to end
- [04-ota-ab.md](docs/04-ota-ab.md) - A/B OTA end to end
- [05-encryption.md](docs/05-encryption.md) - LUKS + automatic unlock
- [06-secure-boot.md](docs/06-secure-boot.md) - signed bootchain and keys
- [07-tools-and-ci.md](docs/07-tools-and-ci.md) - re-signing, deb chain, CI
- [08-hardening.md](docs/08-hardening.md) - image hardening
- [armbian-ota/README.md](armbian-ota/README.md) - OTA internals
- [CHANGELOG.md](CHANGELOG.md) - versioned changes

## Repository Layout

```text
seeed_armbian_extension/
├── seeed_armbian_extension.sh    # Entry: flag checks + sub-extension dispatch only
├── armbian-ota/                  # OTA build hooks + runtime (common / recovery / ab)
├── rk_secure-disk-encryption/    # Encryption, auto-unlock, secure boot hooks
├── ssh-protect/                  # SSH power-loss recovery (always enabled)
├── initramfs/                    # Boot-device root anchor (init-top)
├── rk-uboot-postprocess/         # U-Boot post-processing (always enabled)
├── security-hardening/           # Board security hardening (always enabled)
├── scripts/                      # build.sh, repack-fit.sh, deb release chain
└── docs/                         # The guides linked above
```

Board U-Boot defconfigs live in the Armbian build tree
(`patch/u-boot/legacy/u-boot-radxa-rk35xx/defconfig/`); secure-boot
fragments, kernel FIT ITS templates and the ATF+OP-TEE FIT generator live
in `rk_secure-disk-encryption/u-boot/`.

## Entry-Script Rules

`seeed_armbian_extension.sh` only composes flags — it implements nothing:

1. `RK_SECURE_UBOOT_ENABLE` and `RK_OPTEE_BOOT_ENABLE` are mutually
   exclusive; either one auto-enables `CRYPTROOT_ENABLE=yes` +
   `RK_AUTO_DECRYP=yes`, and `RK_AUTO_DECRYP` alone is rejected.
2. Auto-decrypt forces `CRYPTROOT_SSH_UNLOCK=no` — the unlock passphrase
   has exactly one source, no SSH side channel.
3. `OTA_ENABLE=yes` enables the OTA hooks (mode selected by
   `AB_PART_OTA`).

The build hard-fails a passphrase that is not exactly 64 characters; use
64 **hexadecimal** characters — only hex round-trips through the OP-TEE
keybox ([05-encryption.md](docs/05-encryption.md)).
