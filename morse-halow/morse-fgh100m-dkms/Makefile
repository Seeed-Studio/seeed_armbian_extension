# DKMS wrapper Makefile for Morse Micro FG-H100M HaLow WiFi driver
KSRC ?= /lib/modules/$(shell uname -r)/build
KERNEL_SRC ?= $(KSRC)
PWD := $(shell pwd)

# Force-enable config options for out-of-tree build
OVERRIDES = \
	CONFIG_WLAN_VENDOR_MORSE=m \
	CONFIG_MORSE_SPI=y \
	CONFIG_MORSE_USER_ACCESS=y \
	CONFIG_MORSE_VENDOR_COMMAND=y \
	CONFIG_MORSE_MONITOR=y \
	CONFIG_MORSE_DEBUG_MASK=1 \
	KERNEL_SRC=$(KERNEL_SRC)

# Newer Rockchip vendor 6.1 trees backported the td_bitmap/td_bitmap_len
# args of cfg80211_port_authorized() without bumping LINUX_VERSION_CODE
# (6.1.172 ships with both signatures), so version macros cannot pick the
# right call form. Probe the header we are about to build against instead
# and let src/Makefile map the flag to -DCFG80211_PORT_AUTH_TD_BITMAP.
CFG80211_H := $(KSRC)/include/net/cfg80211.h
ifeq ($(shell grep -qs td_bitmap $(CFG80211_H) && echo y),y)
OVERRIDES += CONFIG_MORSE_PORT_AUTH_TD_BITMAP=y
endif

all:
	$(MAKE) -C $(KSRC) M=$(PWD)/src $(OVERRIDES) modules

install:
	$(MAKE) -C $(KSRC) M=$(PWD)/src $(OVERRIDES) modules_install INSTALL_MOD_PATH=$(DESTDIR)

clean:
	$(MAKE) -C $(KSRC) M=$(PWD)/src clean
