# DKMS wrapper Makefile for the Maxio MAE0621A Ethernet PHY driver
KSRC ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

obj-m += src/maxio.o

all:
	$(MAKE) -C $(KSRC) M=$(PWD) modules

install:
	$(MAKE) -C $(KSRC) M=$(PWD) modules_install INSTALL_MOD_PATH=$(DESTDIR)

clean:
	$(MAKE) -C $(KSRC) M=$(PWD) clean
