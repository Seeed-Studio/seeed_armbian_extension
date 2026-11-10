# morse-firmware

Deb packaging of the Morse Micro Wi-Fi HaLow firmware for the Wio-WM6108
module (Quectel FGH100M-H, MM6108 silicon).

Snapshot of https://github.com/MorseMicro/morse-firmware at commit
`974c7744263ffb56a1c8678962e740fdcb3428f7` (2025-12-07) — the same pin the
image build previously fetched at build time via `fetch_from_repo` in
armbian-build's `recomputer-rk35xx-common.inc`
(`post_family_tweaks_bsp__recomputer_fgh100m_morse_firmware`).

Installed files:

| file                              | upstream source                   | purpose                     |
|-----------------------------------|-----------------------------------|-----------------------------|
| /lib/firmware/morse/mm6108.bin    | firmware/mm6108.bin               | MM6108 standard firmware    |
| /lib/firmware/morse/bcf_default.bin | bcf/quectel/bcf_fgh100mhaamd.bin | FGH100M-H (US) BCF board config |

The package `Replaces:` the `armbian-bsp-cli/desktop-*` debs that shipped
these paths before, so existing images can install it without a dpkg file
conflict.

## Updating the firmware

Copy the new bins into `firmware/` keeping the same names, then add a
`debian/changelog` entry recording the new upstream commit (version as
`YYYYMMDD-N` of the commit date). Firmware must stay compatible with the
`morse-fgh100m-dkms` driver version published alongside it.
