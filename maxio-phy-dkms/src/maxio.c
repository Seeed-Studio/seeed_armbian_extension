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
 * The Q3C variant also needs the vendor clock, analogue-front-end and
 * power-management sequences. Without them the RGMII clock can stop when
 * the interface is reopened, leaving the MAC's DMA reset waiting forever.
 * Those sequences are ported from Maxio's Linux driver, including the
 * v1.9.1.2 Q3C analogue tuning updates.
 *
 * The LED sequence also runs as a PHY fixup registered for this PHY's UID:
 * this tree's MDIO probe can race the generic driver into binding, in
 * which case config_init would never run. Both paths are idempotent.
 * The fixup path uses plain phy_write() with manual page selects --
 * the paged helpers' unlocked __phy_read path is not safe in the
 * phy_scan_fixups context.
 */

#include <linux/module.h>
#include <linux/delay.h>
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

#define MAXIO_PHY_VER			"v1.9.1.2"

struct maxio_reg_write {
	u16 page;
	u16 reg;
	u16 value;
};

/* Vendor Q3C sequence. Keep page 0 selected between operations so an
 * interrupted initialization cannot affect the next PHY user.
 */
static const struct maxio_reg_write maxio_q3c_init[] = {
	{ 0xa43, 0x19, 0x0823 }, /* CLKOUT enabled, 125 MHz */
	{ 0xdab, 0x17, 0x0c13 },
	{ 0xd96, 0x15, 0xc08a },
	{ 0xda4, 0x12, 0x07bc },
	{ 0xd8f, 0x16, 0x2500 },
	{ 0xd90, 0x16, 0x1555 },
	{ 0xd92, 0x11, 0x2b15 },
	{ 0xd96, 0x16, 0x4010 },
	{ 0xda5, 0x11, 0x4a12 },
	{ 0xda5, 0x12, 0x4a12 },
	{ 0xd99, 0x16, 0x000a },
	{ 0xd95, 0x13, 0x5b00 },
	{ 0xd8f, 0x10, 0x0300 },
	{ 0xd98, 0x17, 0x8506 },
	{ 0xd95, 0x12, 0x6870 },
	{ 0xd93, 0x15, 0x0940 },
	{ 0xd93, 0x11, 0x4434 },
	{ 0xdad, 0x12, 0x1303 },
	{ 0xda8, 0x10, 0x0999 },
	{ 0xda8, 0x11, 0x0177 },
	{ 0xda8, 0x12, 0x0868 },
	{ 0xa42, 0x12, 0x0028 },
	{ 0x000, 0x04, 0x0de1 },
};

static int maxio_write_paged(struct phy_device *phydev, u16 page, u16 reg,
			     u16 value)
{
	int ret, ret2;

	ret = phy_write(phydev, MAE0621A_PAGE_SELECT, page);
	if (ret < 0)
		return ret;

	ret = phy_write(phydev, reg, value);
	ret2 = phy_write(phydev, MAE0621A_PAGE_SELECT, 0);

	return ret < 0 ? ret : ret2;
}

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
	int ret, i;

	phydev_info(phydev, "MAXIO_PHY_VER: %s\n", MAXIO_PHY_VER);

	for (i = 0; i < ARRAY_SIZE(maxio_q3c_init); i++) {
		const struct maxio_reg_write *w = &maxio_q3c_init[i];

		ret = maxio_write_paged(phydev, w->page, w->reg, w->value);
		if (ret < 0) {
			phydev_err(phydev,
				   "Q3C init failed at page %#x reg %#x: %d\n",
				   w->page, w->reg, ret);
			return ret;
		}
	}

	/* Soft reset and restart autonegotiation after the analogue setup. */
	ret = maxio_write_paged(phydev, 0, MII_BMCR, 0x9140);
	if (ret < 0)
		return ret;

	msleep(100);
	return maxio_led_init(phydev);
}

static int maxio_suspend(struct phy_device *phydev)
{
	int ret, ret2;

	ret = maxio_write_paged(phydev, 0xdaa, 0x17, 0x1011);
	if (ret < 0)
		return ret;

	ret = maxio_write_paged(phydev, 0xdab, 0x15, 0x5550);
	if (ret < 0)
		return ret;

	ret = genphy_suspend(phydev);
	ret2 = phy_write(phydev, MAE0621A_PAGE_SELECT, 0);

	return ret < 0 ? ret : ret2;
}

static int maxio_resume(struct phy_device *phydev)
{
	int ret, ret2;

	ret = genphy_resume(phydev);
	if (ret < 0)
		return ret;

	ret = maxio_write_paged(phydev, 0xdaa, 0x17, 0x1001);
	if (ret < 0)
		return ret;

	ret = maxio_write_paged(phydev, 0xdab, 0x15, 0x0000);
	ret2 = maxio_led_init(phydev);

	return ret < 0 ? ret : ret2;
}

static struct phy_driver maxio_driver[] = {
	{
		PHY_ID_MATCH_EXACT(PHY_ID_MAE0621A),
		.name		= "Maxio MAE0621A Gigabit Ethernet",
		.config_init	= maxio_config_init,
		.suspend	= maxio_suspend,
		.resume		= maxio_resume,
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
		return ret;

	/* This vendor 6.1 tree rejects a module whose reference count is
	 * still zero, preventing stmmac from attaching the PHY. A NULL owner
	 * bypasses that check. Keep this board-specific driver resident so
	 * its callbacks cannot be unloaded while the PHY is using them.
	 */
	ret = phy_drivers_register(maxio_driver, ARRAY_SIZE(maxio_driver),
				   NULL);
	if (ret)
		phy_unregister_fixup_for_uid(PHY_ID_MAE0621A, 0xffffffff);

	return ret;
}
module_init(maxio_init);
/* No module_exit(): the kernel rejects rmmod for this resident driver. */

static const struct mdio_device_id __maybe_unused maxio_tbl[] = {
	{ PHY_ID_MATCH_EXACT(PHY_ID_MAE0621A) },
	{ }
};
MODULE_DEVICE_TABLE(mdio, maxio_tbl);

MODULE_DESCRIPTION("Maxio MAE0621A-Q3C Ethernet PHY driver");
MODULE_AUTHOR("Ming Zhangqun <north_sea@qq.com>");
MODULE_AUTHOR("Zhao Yang <yang_zhao@maxio-tech.com>");
MODULE_LICENSE("GPL");
