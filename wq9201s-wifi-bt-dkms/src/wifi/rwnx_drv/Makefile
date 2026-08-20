# SPDX-License-Identifier: GPL-2.0
#
# Makefile for WuQi WLAN device drivers.
#

#
# FIXME: put CONFIG_WQ_WLAN and CONFIG_WQ_WLAN_XXX into Kconfig
#

CONFIG_WQ_WLAN_ALL_IN_ONE ?= m

CONFIG_WQ_WLAN_CORE ?= m

# supported H/W bus
CONFIG_WQ_WLAN_USB ?= m
CONFIG_WQ_WLAN_SDIO ?= m
CONFIG_WQ_WLAN_PCIE ?= m

CONFIG_WQ_WLAN_FPGA ?= y
ifeq ($(CONFIG_HW_PLATFORM), EMU_FPGA)
# for compatiablity, support legacy option CONFIG_HW_PLATFORM
CONFIG_WQ_WLAN_FPGA := y
endif

CONFIG_WQ_DTOP ?= y

# Enable A-MSDU support (need FW support)
## Select this if FW is compiled with AMSDU support
CONFIG_RWNX_SPLIT_TX_BUF ?= y
## Select this TO send AMSDU
CONFIG_RWNX_AMSDUS_TX ?= y
### AMSDU timer select
CONFIG_RWNX_USE_HRT ?= n

# set support 5G channel
CONFIG_SUPPORT_5G_BAND ?= y

# Enable dual-sdio chip support
CONFIG_DUAL_SDIO_SUPPORT ?= n

# Enable dual-usb chip support
CONFIG_DUAL_USB_SUPPORT ?= n

# Amlogic-T982 platform compilation compatibility:
## this kernel is Linux 5.15.78, but with backward porting of Linux 6.0+, 
## so add this config macro support it.
CONFIG_AMLOGIC_BUILD_COMPATIBLE ?= n

# Android GKI version compatible
CONFIG_WQ_GKI ?= n

ifeq ($(CONFIG_WQ_WLAN_ALL_IN_ONE), n)
 ifeq ($(CONFIG_DUAL_SDIO_SUPPORT), y)
 CONFIG_EXT_NAME = "_1"
 else
 CONFIG_EXT_NAME = ""
 endif
endif

# Enable BFMER support (need FW support)
CONFIG_RWNX_BFMER ?= n

# Support of MU-MIMO transmission (need FW support)
ifeq ($(CONFIG_RWNX_BFMER), y)
CONFIG_RWNX_MUMIMO_TX ?= n
else
CONFIG_RWNX_MUMIMO_TX = n
endif

# Enable SDR support (need FW support)
CONFIG_SDR ?= n

# Enable statistics of trx for each sta and each tid (need FW support)
CONFIG_TRX_STAT ?= n

# Enable handling of radar event
CONFIG_RWNX_RADAR ?= n

# Enable HW queue for Broadcast/Multicast traffic (need FW support)
CONFIG_RWNX_BCMC ?= y

# Enable Monitor+Data interface support (need FW support)
CONFIG_RWNX_MON_DATA ?= n

# Profiling
CONFIG_RWNX_PROF ?=y

# extra DEBUG config
CONFIG_DEBUG_WQ_DFX ?= y

#
# previously CONFIG_HML=y, but TASK_VENDOR is not same as firmware's.
# that's to say, related feature under this MACRO doesn't work actually.
# after fix it, should confirm they work as well.
#
CONFIG_HML ?= y

# Support of P2P DebugFS for enabling/disabling NoA and OppPS
CONFIG_RWNX_P2P_DEBUGFS ?= y

# tx/rx Calibration Mode
# bit-0 : enable Rx DCC calibration
# bit-1 : enable Tx DCC calibration
# bit-2 : enable Tx IQMC calibration
# bit-3 : enable Rx IQMC calibration
CONFIG_TXRX_CALIB_MODE ?= 0xF

CONFIG_RX_THREAD ?= y

## NAPI support
CONFIG_RWNX_NAPI ?= y

## tx IPI support
CONFIG_RWNX_TX_IPI ?= n

## WQ PM support
CONFIG_WQ_WLAN_PM ?= m

## TX bus qos support
CONFIG_TX_BUS_QOS ?= n

## cpu bind or not
CONFIG_WQ_CPU_UNBIND ?= n

# contains common defintions between host and firmware
SRC_COMMON := ../../common

OBJ_ROOT :=
OBJ_MAC := fullmac/
OBJ_MISC := misc/
OBJ_APP := app/
OBJ_IPC := ipc/
OBJ_BMI := ipc/bmi/
OBJ_HTC := ipc/htc/
OBJ_HIF := ipc/hif/
OBJ_PCIE := ipc/hif/pcie/
OBJ_SDIO := ipc/hif/sdio/
OBJ_USB := ipc/hif/usb/
OBJ_PLAT := platform/

#
# wq_wlan_core
#
wq_wlan_core-y += $(OBJ_ROOT)core.o
wq_wlan_core-y += $(OBJ_ROOT)config.o
wq_wlan_core-y += $(OBJ_ROOT)hal_desc.o
wq_wlan_core-y += $(OBJ_ROOT)rwnx_cmds.o
wq_wlan_core-y += $(OBJ_ROOT)rwnx_mod_params.o
wq_wlan_core-y += $(OBJ_ROOT)rwnx_msg_rx.o
wq_wlan_core-y += $(OBJ_ROOT)rwnx_msg_tx.o
wq_wlan_core-y += $(OBJ_ROOT)rwnx_strs.o
wq_wlan_core-y += $(OBJ_ROOT)rwnx_txq.o
wq_wlan_core-y += $(OBJ_ROOT)rwnx_utils.o
wq_wlan_core-y += $(OBJ_ROOT)rwnx_reg_data.o
wq_wlan_core-y += $(OBJ_MAC)ieee80211_ht.o
wq_wlan_core-y += $(OBJ_MAC)ieee80211_extap.o
wq_wlan_core-y += $(OBJ_MAC)rwnx_main.o
wq_wlan_core-y += $(OBJ_MAC)rwnx_mesh.o
wq_wlan_core-y += $(OBJ_MAC)rwnx_rx.o
wq_wlan_core-y += $(OBJ_MAC)rwnx_tdls.o
wq_wlan_core-y += $(OBJ_MAC)rwnx_tx.o
wq_wlan_core-y += $(OBJ_MAC)wq_pkt_classify.o
wq_wlan_core-y += $(OBJ_MAC)wq_rx_defrag.o
wq_wlan_core-y += $(OBJ_MAC)wlan_ioctl.o
wq_wlan_core-y += $(OBJ_MAC)country.o
wq_wlan_core-$(CONFIG_WQ_DTOP) += $(OBJ_MISC)coex.o
ifeq ($(CONFIG_WQ_GKI), n)
wq_wlan_core-y += $(OBJ_MAC)wq_pktlog.o
wq_wlan_core-$(CONFIG_WQ_DTOP) += $(OBJ_MISC)dtop_main.o
wq_wlan_core-$(CONFIG_WQ_DTOP) += $(OBJ_APP)fw_dbg.o
wq_wlan_core-y += $(OBJ_APP)fw_log.o
endif
wq_wlan_core-y += $(OBJ_MISC)proc.o
wq_wlan_core-y += $(OBJ_MISC)mp_test.o
wq_wlan_core-y += $(OBJ_MISC)wq_crc.o
wq_wlan_core-y += $(OBJ_MISC)wq_wifi_dbg.o
wq_wlan_core-$(CONFIG_RWNX_PROF) += $(OBJ_MISC)wq_profiling.o
wq_wlan_core-y += $(OBJ_HTC)htc.o
wq_wlan_core-y += $(OBJ_HTC)wq_tx_credit.o
wq_wlan_core-y += $(OBJ_IPC)wq_ipc.o
wq_wlan_core-y += $(OBJ_BMI)bmi_core.o
wq_wlan_core-y += $(OBJ_BMI)bmi_cmd.o
wq_wlan_core-y += $(OBJ_BMI)wq_dnld.o
wq_wlan_core-y += $(OBJ_BMI)bmi_dnld.o
wq_wlan_core-$(CONFIG_CPU_RK3588) += $(OBJ_PLAT)plat_rk3588.o
wq_wlan_core-$(CONFIG_SOC_SPACEMIT_K1) += $(OBJ_PLAT)plat_spacemit_k1.o

wq_wlan_core-y += $(OBJ_MAC)rwnx_rx_ll.o

wq_wlan_core-$(CONFIG_RWNX_RADAR)       += $(OBJ_ROOT)rwnx_radar.o
wq_wlan_core-$(CONFIG_DEBUG_WQ_PRIV)    += $(OBJ_MISC)wq_wifi_priv.o
wq_wlan_core-$(CONFIG_DEBUG_FS)         += $(OBJ_ROOT)rwnx_debugfs.o
wq_wlan_core-$(CONFIG_DEBUG_FS)         += $(OBJ_ROOT)rwnx_fw_dump.o
wq_wlan_core-$(CONFIG_DEBUG_FS)         += $(OBJ_ROOT)rwnx_fw_trace.o
wq_wlan_core-$(CONFIG_RWNX_BFMER)       += $(OBJ_ROOT)rwnx_bfmer.o
wq_wlan_core-$(CONFIG_RWNX_MUMIMO_TX)   += $(OBJ_ROOT)rwnx_mu_group.o

#
# wq_wlan_xxxx for specific H/W bus
#
ifeq ($(CONFIG_WQ_GKI), n)
wq_wlan_usb-$(CONFIG_WQ_DTOP) += $(OBJ_USB)usb_dtop.o
endif
wq_wlan_usb-y += $(OBJ_USB)usb.o
wq_wlan_usb-y += $(OBJ_USB)urb_ctx.o
wq_wlan_usb-y += $(OBJ_USB)usb_bundle.o
wq_wlan_usb-y += $(OBJ_USB)usb_dnld.o

wq_wlan_sdio$(CONFIG_EXT_NAME)-y += $(OBJ_SDIO)sdio.o
wq_wlan_sdio$(CONFIG_EXT_NAME)-y += $(OBJ_SDIO)sdio_adma.o
wq_wlan_sdio$(CONFIG_EXT_NAME)-y += $(OBJ_SDIO)skbreq_queue.o
wq_wlan_sdio$(CONFIG_EXT_NAME)-y += $(OBJ_SDIO)sdio_dnld.o
wq_wlan_sdio$(CONFIG_EXT_NAME)-y += $(OBJ_SDIO)sdio_test.o

wq_wlan_pcie-y += $(OBJ_PCIE)ce.o
wq_wlan_pcie-y += $(OBJ_PCIE)pcie_dnld.o
wq_wlan_pcie-y += $(OBJ_PCIE)pcie.o
ifeq ($(CONFIG_WQ_GKI), n)
wq_wlan_pcie-$(CONFIG_WQ_DTOP) += $(OBJ_PCIE)pcie_dtop.o
endif
wq_wlan_pcie-$(CONFIG_PCIE_UNIT_TEST) += $(OBJ_PCIE)ce_test.o
wq_wlan_pcie-$(CONFIG_PCIE_UNIT_TEST) += $(OBJ_PCIE)pcie_test.o

ifeq ($(CONFIG_WQ_WLAN_ALL_IN_ONE), m)
obj-$(CONFIG_WQ_WLAN_ALL_IN_ONE) += wq_wlan$(MULTI_KO).o
wq_wlan$(MULTI_KO)-y := main.o $(wq_wlan_core-y)
wq_wlan$(MULTI_KO)-y += $(OBJ_HIF)hif_comm.o
ccflags-y += -DWQ_WLAN_ALL_IN_ONE
ifeq ($(CONFIG_WQ_WLAN_USB), m)
wq_wlan$(MULTI_KO)-y += $(wq_wlan_usb-y)
ccflags-y += -DCONFIG_WQ_WLAN_USB
endif
ifeq ($(CONFIG_WQ_WLAN_SDIO), m)
wq_wlan$(MULTI_KO)-y += $(wq_wlan_sdio-y)
ccflags-y += -DCONFIG_WQ_WLAN_SDIO
endif
ifeq ($(CONFIG_WQ_WLAN_PCIE), m)
wq_wlan$(MULTI_KO)-y += $(wq_wlan_pcie-y)
ccflags-y += -DCONFIG_WQ_WLAN_PCIE
endif
else
obj-$(CONFIG_WQ_WLAN_CORE) += wq_wlan_core.o
obj-$(CONFIG_WQ_WLAN_USB) += wq_wlan_usb.o
obj-$(CONFIG_WQ_WLAN_SDIO) += wq_wlan_sdio$(CONFIG_EXT_NAME).o
obj-$(CONFIG_WQ_WLAN_PCIE) += wq_wlan_pcie.o
wq_wlan_usb-y += $(OBJ_HIF)hif_comm.o
wq_wlan_pcie-y += $(OBJ_HIF)hif_comm.o
wq_wlan_sdio$(CONFIG_EXT_NAME)-y += $(OBJ_HIF)hif_comm.o

endif

ifeq ($(CONFIG_SDR), y)
ccflags-y += -DCONFIG_SDR
endif

ifeq ($(CONFIG_TRX_STAT), y)
ccflags-y += -DCONFIG_TRX_STAT
endif

# include files
ccflags-y += -I$(src)
ccflags-y += -I$(src)/$(SRC_COMMON)
# copy of $(SRC_COMMON) for smoke_build or released SDK
ccflags-y += -I$(src)/$(shell basename $(SRC_COMMON))
ccflags-y += -I$(src)/fullmac
ccflags-y += -I$(src)/ipc
ccflags-y += -I$(src)/ipc/bmi
ccflags-y += -I$(src)/ipc/hif
ccflags-y += -I$(src)/ipc/hif/pcie
ccflags-y += -I$(src)/ipc/hif/pcie/pcie_host
ccflags-y += -I$(src)/ipc/hif/sdio
ccflags-y += -I$(src)/ipc/hif/usb
ccflags-y += -I$(src)/ipc/htc
ccflags-y += -I$(src)/misc
ccflags-y += -I$(src)/app
ccflags-y += -I$(src)/platform

# FPGA or ASIC?
ccflags-$(CONFIG_WQ_WLAN_FPGA) += -DWQ_WLAN_FPGA

# USB options
ccflags-y += -DWQ_MSG_EP_TYPE=3		# EP_TYPE: 2(BULK), 3(INT)

# Multi wlan chips support
ifneq (,$(filter 1 0, $(MULTI_KO)))
ccflags-y += -DMULTI_CHIP=$(MULTI_KO)
endif

# features
ccflags-$(CONFIG_AMLOGIC_BUILD_COMPATIBLE) += -DAMLOGIC_BUILD_COMPATIBLE
ccflags-$(CONFIG_WQ_GKI) += -DCONFIG_WQ_GKI
ccflags-$(CONFIG_DUAL_SDIO_SUPPORT) += -DDUAL_SDIO_SUPPORT
ccflags-$(CONFIG_DUAL_USB_SUPPORT) += -DDUAL_USB_SUPPORT
ccflags-$(CONFIG_SUPPORT_5G_BAND) += -DSUPPORT_5G_BAND
ccflags-$(CONFIG_RWNX_RADAR) += -DCONFIG_RWNX_RADAR
ccflags-$(CONFIG_RWNX_MON_DATA) += -DCONFIG_RWNX_MON_DATA
ccflags-$(CONFIG_RWNX_BFMER) += -DCONFIG_RWNX_BFMER
ccflags-$(CONFIG_RWNX_SPLIT_TX_BUF) += -DCONFIG_RWNX_SPLIT_TX_BUF
ifeq ($(CONFIG_RWNX_SPLIT_TX_BUF), y)
ccflags-$(CONFIG_RWNX_AMSDUS_TX) += -DCONFIG_RWNX_AMSDUS_TX
endif
ccflags-$(CONFIG_RWNX_MUMIMO_TX) += -DCONFIG_RWNX_MUMIMO_TX

ccflags-$(CONFIG_PCIE_UNIT_TEST) += -DCONFIG_PCIE_UNIT_TEST
ccflags-$(CONFIG_SDIO_UNIT_TEST) += -DCONFIG_SDIO_UNIT_TEST
ccflags-y += -DWQ_TXRX_CALIB_MODE=$(CONFIG_TXRX_CALIB_MODE)
ccflags-$(CONFIG_RX_THREAD)      += -DCONFIG_RX_THREAD

ifeq ($(CONFIG_RWNX_MUMIMO_TX), y)
ccflags-y += -DCONFIG_USER_MAX=2
else
ccflags-y += -DCONFIG_USER_MAX=1
endif

ifeq ($(CONFIG_RWNX_BCMC), y)
ccflags-y += -DNX_TXQ_CNT=5
else
ccflags-y += -DNX_TXQ_CNT=4
endif

ifeq ($(CONFIG_RWNX_NAPI), y)
ccflags-y += -DNAPI_SUPPORT
endif

ifeq ($(CONFIG_RWNX_TX_IPI), y)
ccflags-y += -DTX_IPI_SUPPORT
endif

ifeq ($(CONFIG_RWNX_USE_HRT), y)
ccflags-y += -DUSE_HRT
endif

ifeq ($(CONFIG_WQ_DTOP), y)
ccflags-y += -DCONFIG_WQ_DTOP
endif

ifeq ($(CONFIG_WQ_WLAN_PM), m)
ccflags-y += -DCONFIG_WQ_WLAN_PM
endif

ifeq ($(CONFIG_TX_BUS_QOS), y)
ccflags-y += -DCONFIG_TX_BUS_QOS
endif

ccflags-$(CONFIG_DEBUG_WQ_PRIV) += -DDEBUG_WQ_PRIV
ccflags-$(CONFIG_DEBUG_WQ_DFX) += -DDEBUG_WQ_DFX

ccflags-$(CONFIG_DEBUG_FS) += -DCONFIG_RWNX_DEBUGFS
ccflags-$(CONFIG_RWNX_P2P_DEBUGFS) += -DCONFIG_RWNX_P2P_DEBUGFS

ccflags-$(CONFIG_CPU_RK3588) += -DCONFIG_RK3588_ENABLE_WAKEUP_OOB
ccflags-$(CONFIG_SOC_SPACEMIT_K1) += -DCONFIG_SPACEMIT_K1_SDIO_WAR
ccflags-$(CONFIG_SOC_AML) += -DCONFIG_SOC_AML

ccflags-$(CONFIG_WAR_CE_INTR_FAST_THAN_DATA) += -DCONFIG_WAR_CE_INTR_FAST_THAN_DATA
ccflags-$(CONFIG_WQ_CPU_UNBIND) += -DWQ_CPU_UNBIND

# FW VARS
#ccflags-y += -DNX_VIRT_DEV_MAX=4
#ccflags-y += -DNX_REMOTE_STA_MAX=32
ccflags-y += -DNX_MU_GROUP_MAX=62
ccflags-y += -DNX_TXDESC_CNT=64
ccflags-y += -DNX_TX_MAX_RATES=4
ccflags-y += -DNX_CHAN_CTXT_CNT=4

ccflags-y += -DWQ_HW_MAC_MAX=2
ccflags-y += -DWQ_HE_STA

ccflags-$(CONFIG_HML) += -DCONFIG_HML

# FW ARCH:
ccflags-$(CONFIG_RWNX_SDM) += -DCONFIG_RWNX_SDM

ccflags-y += -Werror
ccflags-y += -g

VAR1 := .
ifeq ($(srctree), $(VAR1))
VAR2 := $(if $(KBUILD_EXTMOD),,$(PWD)/)$(src)/wq_version_gen.h
else
VAR2 := $(if $(KBUILD_EXTMOD),,$(srctree)/)$(src)/wq_version_gen.h
endif

#
# easy to make these kernel modules
#
KERNELDIR ?= /lib/modules/`uname -r`/build

all: modules

modules:
	$(MAKE) -C $(KERNELDIR) O=$(KBUILDDIR) M=$(CURDIR) $@

strip:
	@for f in *.ko ; do $(CROSS_COMPILE)strip --strip-debug --strip-unneeded $$f; done

asm:
	@for f in *.ko ; do $(CROSS_COMPILE)objdump -rdl $$f > $$f.asm ; done

#
# alias for smoke test and gating
#
DIR_SMOKE ?= ../smoke

multi_ko:
	mkdir -p $(DIR_SMOKE)/multi_ko
	@cp -ra . $(SRC_COMMON) $(DIR_SMOKE)/multi_ko
	$(MAKE) -j4 -C $(KERNELDIR) O=$(KBUILDDIR) M=$(PWD)/$(DIR_SMOKE)/multi_ko CONFIG_WQ_WLAN_ALL_IN_ONE=n modules

all_in_one:
	@mkdir -p $(DIR_SMOKE)/all_in_one
	@cp -ra . $(SRC_COMMON) $(DIR_SMOKE)/all_in_one
	$(MAKE) -j4 -C $(KERNELDIR) O=$(KBUILDDIR) M=$(PWD)/$(DIR_SMOKE)/all_in_one modules

smoke_build: multi_ko all_in_one
	@echo WuQi wlan all-in-one driver: $(shell readlink -f "$(DIR_SMOKE)/all_in_one/wq_wlan.ko")

clean:
	$(MAKE) -C $(KERNELDIR) O=$(KBUILDDIR) M=$(CURDIR) $@
	@rm -fr $(DIR_SMOKE)

help:
	@echo "Example:"
	@echo " * build wq_wlan.ko (all in one driver)"
	@echo "	make -j4"
	@echo " * build wq_wlan.ko for usb and sdio (exclude pcie)"
	@echo "	make -j4 CONFIG_WQ_WLAN_PCIE=n"
	@echo " * build wq_wlan_core.ko, wq_wlan_usb.ko, wq_wlan_sdio.ko and wq_wlan_pcie.ko"
	@echo "	make -j4 CONFIG_WQ_WLAN_ALL_IN_ONE=n"

quiet_cmd_genvers = GENVERSION $@
      cmd_genvers = ($(if $(KBUILD_EXTMOD),,$(srctree)/)$(src)/mkvers.sh  $(VAR2) )

# To avoid always regenerating wq_version_gen.h (i.e. depend on FORCE), add
# dependency on all object (which already include dependency on headers files).
# Still Cannot add dependency on rwnx_main.o otherwise this will create circular
# dependency, so instead add dependency only on rwnx_main.c. This will fail to
# regenerate wq_version_gen.h if dependency of only rwnx_main.c is changed.
# This is OK as, currently, the only such dependency is core.c
$(obj)/core.o: $(obj)/wq_version_gen.h
$(obj)/wq_version_gen.h: $(addprefix $(obj)/,$(filter-out core.o, $(wq_wlan_core-y))) $(src)/core.c
	$(call cmd,genvers)

clean-dirs := $(DIR_SMOKE)
clean-files := wq_version_gen.h
