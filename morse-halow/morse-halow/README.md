# morse-halow

Metapackage that installs the complete, version-locked Morse Wi-Fi HaLow
stack for the Wio-WM6108 module (Quectel FGH100M-H) with one
`apt install morse-halow`:

| pinned package                | version   | role                        |
|-------------------------------|-----------|-----------------------------|
| morse-fgh100m-dkms            | 1.16.4-3  | kernel driver (DKMS)        |
| morse-firmware                | 20251207-1| MM6108 firmware + BCF       |
| hostapd-morse-tools           | 1.0-1     | patched hostapd (AP mode)   |
| wpa-supplicant-morse-tools    | 1.0-1     | patched wpa_supplicant (STA)|
| morsectrl-tools               | 1.0-1     | morsectrl CLI               |

All pins are exact `(=)` — driver, firmware and userspace tools must
upgrade in lockstep, so any version bump in the family requires a new
revision of this package (edit `debian/control` + changelog entry; no
build step).

The image build installs just this package for
`SEEED_MORSE_ENABLE=yes` (see `recomputer-rk35xx-common.inc` in
Seeed-Studio/armbian-build).

Removal: `apt remove morse-halow && apt autoremove` (the pinned stack is
auto-installed and autoremove cleans it once the meta is gone).
