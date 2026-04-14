# usbdevice gadget deb

## Contents
- `usbdevice-gadget-deb/usr/bin/usbdevice`
- `usbdevice-gadget-deb/etc/systemd/system/usbdevice.service`
- `usbdevice-gadget-deb/etc/init.d/.usb_config`

## Build
```bash
./build-usbdevice-deb.sh
```

## Install
```bash
sudo dpkg -i usbdevice-gadget-rk3588_1.0.0_arm64.deb
```

## Service Management
```bash
sudo systemctl daemon-reload
sudo systemctl enable usbdevice.service
sudo systemctl restart usbdevice.service
sudo systemctl status usbdevice.service
```

## Gadget Function Switching
`usbdevice` reads `/etc/init.d/.usb_config` and applies functions on restart.

### Permanent switch (survives reboot)
```bash
echo usb_acm_en   | sudo tee /etc/init.d/.usb_config
sudo systemctl restart usbdevice.service
```

### Temporary switch (not persistent)
```bash
echo usb_rndis_en | sudo tee /tmp/.usb_config
sudo /usr/bin/usbdevice restart
```

## Supported Function Keys
- `usb_adb_en`   : ADB gadget
- `usb_rndis_en` : USB virtual ethernet (RNDIS)
- `usb_acm_en`   : USB virtual serial (ACM)
- `usb_ums_en`   : USB mass storage
- `usb_uac1_en`  : USB audio class v1
- `usb_uac2_en`  : USB audio class v2

## Common Examples
### 1) Enable ACM serial gadget
```bash
echo usb_acm_en | sudo tee /etc/init.d/.usb_config
sudo systemctl restart usbdevice.service
```

### 2) Enable RNDIS gadget
```bash
echo usb_rndis_en | sudo tee /etc/init.d/.usb_config
sudo systemctl restart usbdevice.service
```

### 3) Enable ADB gadget
```bash
echo usb_adb_en | sudo tee /etc/init.d/.usb_config
sudo systemctl restart usbdevice.service
```
Note: `adbd` binary must exist (default path: `/usr/bin/adbd`), otherwise ADB function is skipped.

### 4) Composite mode (example: ADB + ACM)
```bash
cat <<'EOF' | sudo tee /etc/init.d/.usb_config
usb_adb_en
usb_acm_en
EOF
sudo systemctl restart usbdevice.service
```

## OTG Role Check / Switch
```bash
# Check role for 3588
cat /sys/kernel/debug/usb/fc000000.usb/mode

# Force device mode for 3588
echo device | sudo tee /sys/kernel/debug/usb/fc000000.usb/mode

# Force host mode for 3588
echo host | sudo tee /sys/kernel/debug/usb/fc000000.usb/mode
```

## Debug Commands
```bash
# usbdevice runtime log
tail -f /tmp/usbdevice.log

# UDC status
cat /sys/class/udc/fc000000.usb/state

# Gadget tree
find /sys/kernel/config/usb_gadget/rockchip -maxdepth 3 -print
```
