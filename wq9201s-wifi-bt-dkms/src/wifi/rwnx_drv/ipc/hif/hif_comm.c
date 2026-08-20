/*
 * hif_comm.c
 *	used for HIF layer common API abstraction
 *
 *  Created on: Jun 3, 2024
 *      Author: Tommy Wu
 */

#include <linux/version.h>
#include <linux/module.h>
#include "hif_api.h"

char *wq_band = "dual";  /* insmod wq_wlan.ko band=2g / 5g / dual */
module_param_named(band, wq_band, charp, 0);
MODULE_PARM_DESC(band, "Wi-Fi band: dual|2g|5g");

enum wq_band_mode wq_band_pick()
{
	if (!wq_band) return WQ_BAND_DUAL;
	if (!strcmp(wq_band, "2g"))  return WQ_BAND_2G;
	if (!strcmp(wq_band, "5g"))  return WQ_BAND_5G;
	return WQ_BAND_DUAL;
}

