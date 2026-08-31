#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/version.h>

#include "wq_log.h"

#ifdef WQ_WLAN_ALL_IN_ONE

int __init wq_pcie_init(void);
void __exit wq_pcie_exit(void);

int __init wq_sdio_init(void);
void __exit wq_sdio_exit(void);

int __init wq_usb_init(void);
void __exit wq_usb_exit(void);

#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 5, 0)
	#define MOD_BASE(m) ((m)->core_layout.base)
	#define MOD_SIZE(m) ((m)->core_layout.size)
#else
	#define MOD_BASE(m) ((m)->module_core)
	#define MOD_SIZE(m) ((m)->core_size)
#endif

void wq_dump_module_info(const char *func_name)
{
#if 1
	void *base;
	unsigned long size;

	base = MOD_BASE(THIS_MODULE);
	size = (unsigned long)MOD_SIZE(THIS_MODULE);

	WQ_DBG(DM_GENERIC, DL_ERR, "%s: %s, %px-%px (sz:%lu)\n",
			func_name, THIS_MODULE->name, base, (char *)base + size, size);
#endif
}

static int __init wq_wlan_init(void)
{
	int ret = 0;

	wq_dump_module_info(__func__);

#if IS_ENABLED(CONFIG_WQ_WLAN_PCIE)
	ret = wq_pcie_init();
#endif

#if IS_ENABLED(CONFIG_WQ_WLAN_SDIO)
	ret |= wq_sdio_init();
#endif

#if IS_ENABLED(CONFIG_WQ_WLAN_USB)
	ret |= wq_usb_init();
#endif
	return ret;
}

static void __exit wq_wlan_exit(void)
{
#if IS_ENABLED(CONFIG_WQ_WLAN_USB)
	wq_usb_exit();
#endif
#if IS_ENABLED(CONFIG_WQ_WLAN_SDIO)
	wq_sdio_exit();
#endif
#if IS_ENABLED(CONFIG_WQ_WLAN_PCIE)
	wq_pcie_exit();
#endif

	wq_dump_module_info(__func__);
}

module_init(wq_wlan_init);
module_exit(wq_wlan_exit);

#endif
