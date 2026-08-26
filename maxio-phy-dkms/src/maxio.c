// SPDX-License-Identifier: GPL-2.0+
/*
 * Driver for the Maxio MAE0621A Gigabit Ethernet PHY
 *
 * The MAE0621A is a low-cost RTL8211F-compatible PHY. Basic C22
 * operation works with the generic driver; this driver adds the RJ45
 * LED configuration. The page-select register (0x1f) and the LED
 * control register (page 0xd04, register 0x10) share the RTL8211F
 * layout, verified on the Seeed Studio reComputer Industrial RK3576.
 *
 * The sequence also runs as a PHY fixup registered for this PHY's UID:
 * this tree's MDIO probe can race the generic driver into binding, in
 * which case config_init would never run. Both paths are idempotent.
 * The fixup path uses plain phy_write() with manual page selects --
 * the paged helpers' unlocked __phy_read path is not safe in the
 * phy_scan_fixups context.
 */

#include <linux/module.h>
#include <linux/phy.h>

#define PHY_ID_MAE0621A			0x07b744412

#define MAE0621A_PAGE_SELECT		0x1f
#define MAE0621A_LED_PAGE		0xd04
#define MAE0621A_LEDCR			0x10
#define MAE0621A_LEDCR_MODE		BIT(15)	/* "Mode B" LED mapping */
#define MAE0621A_LEDCR_ACT_TXRX		BIT(4)
#define MAE0621A_LEDCR_LINK_1000	BIT(3)
#define MAE0621A_LEDCR_LINK_100		BIT(1)
#define MAE0621A_LEDCR_LINK_10		BIT(0)
#define MAE0621A_LEDCR_SHIFT		5	/* bits per LED field */

/* LED1 = link at 10/100/1000, LED2 = activity */
#define MAE0621A_LED1_LINK_10_100_1000	\
	((MAE0621A_LEDCR_LINK_10 | MAE0621A_LEDCR_LINK_100 | \
	  MAE0621A_LEDCR_LINK_1000) << (MAE0621A_LEDCR_SHIFT * 1))
#define MAE0621A_LED2_ACTIVITY		\
	(MAE0621A_LEDCR_ACT_TXRX << (MAE0621A_LEDCR_SHIFT * 2))
#define MAE0621A_LEDCR_DEFAULT		\
	(MAE0621A_LEDCR_MODE | MAE0621A_LED1_LINK_10_100_1000 | \
	 MAE0621A_LED2_ACTIVITY)

/* Undocumented LED register next to LEDCR; vendor-recommended value,
 * empirically confirmed on reComputer Industrial RK3576.
 */
#define MAE0621A_LED_REG11		0x11
#define MAE0621A_LED_REG11_VAL		0x0008

static int maxio_led_init(struct phy_device *phydev)
{
	int ret;

	ret = phy_write(phydev, MAE0621A_PAGE_SELECT, MAE0621A_LED_PAGE);
	if (ret < 0)
		goto err;

	ret = phy_write(phydev, MAE0621A_LEDCR, MAE0621A_LEDCR_DEFAULT);
	if (ret < 0)
		goto err;

	ret = phy_write(phydev, MAE0621A_LED_REG11, MAE0621A_LED_REG11_VAL);
	if (ret < 0)
		goto err;

	phy_write(phydev, MAE0621A_PAGE_SELECT, 0);
	return 0;

err:
	phydev_err(phydev, "LED configuration failed: %d\n", ret);
	return ret;
}

static int maxio_config_init(struct phy_device *phydev)
{
	return maxio_led_init(phydev);
}

static struct phy_driver maxio_driver[] = {
	{
		PHY_ID_MATCH_EXACT(PHY_ID_MAE0621A),
		.name		= "Maxio MAE0621A Gigabit Ethernet",
		.config_init	= maxio_config_init,
		.suspend	= genphy_suspend,
		.resume		= genphy_resume,
	},
};

static int __init maxio_init(void)
{
	int ret;

	/* Runs from phy_init_hw() even if the generic driver wins the
	 * bind race in this tree.
	 */
	ret = phy_register_fixup_for_uid(PHY_ID_MAE0621A, 0xffffffff,
					 maxio_led_init);
	if (ret)
		pr_warn("maxio: cannot register PHY fixup: %d\n", ret);

	/* This vendor 6.1 tree patches try_module_get() to also require a
	 * nonzero refcount (atomic_inc_not_zero), so a freshly loaded module
	 * (refcnt 0) always fails it and stmmac cannot attach to the PHY
	 * ("failed to get the device driver module", -EIO). Registering with
	 * a NULL owner matches the built-in generic PHY driver, whose NULL
	 * owner makes try_module_get() a no-op — attachment then works and
	 * config_init configures the LED mode. The module must not be
	 * rmmod'd while attached (no refcount protection), acceptable for a
	 * board PHY driver that loads once at boot.
	 */
	return phy_drivers_register(maxio_driver, ARRAY_SIZE(maxio_driver),
				    NULL);
}
module_init(maxio_init);

static void __exit maxio_exit(void)
{
	phy_drivers_unregister(maxio_driver, ARRAY_SIZE(maxio_driver));
	/* Module form: the fixup callback would dangle after rmmod */
	phy_unregister_fixup_for_uid(PHY_ID_MAE0621A, 0xffffffff);
}
module_exit(maxio_exit);

static const struct mdio_device_id __maybe_unused maxio_tbl[] = {
	{ PHY_ID_MATCH_EXACT(PHY_ID_MAE0621A) },
	{ }
};
MODULE_DEVICE_TABLE(mdio, maxio_tbl);

MODULE_DESCRIPTION("Maxio MAE0621A Ethernet PHY driver");
MODULE_AUTHOR("Ming Zhangqun <north_sea@qq.com>");
MODULE_LICENSE("GPL");
