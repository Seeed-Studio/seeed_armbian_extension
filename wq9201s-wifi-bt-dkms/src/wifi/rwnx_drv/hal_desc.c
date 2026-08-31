/**
 *****************************************************************************
 *
 * @file hal_desc.c
 *
 * Copyright (C) RivieraWaves 2012-2019
 *
 *****************************************************************************
 */

#include <linux/string.h>
#include "hal_desc.h"

const struct rwnx_legrate legrates_lut[] = {
	[0] = { .idx = 0, .rate = 10 },	   [1] = { .idx = 1, .rate = 20 },
	[2] = { .idx = 2, .rate = 55 },	   [3] = { .idx = 3, .rate = 110 },
	[4] = { .idx = -1, .rate = 0 },	   [5] = { .idx = -1, .rate = 0 },
	[6] = { .idx = -1, .rate = 0 },	   [7] = { .idx = -1, .rate = 0 },
	[8] = { .idx = 10, .rate = 480 },  [9] = { .idx = 8, .rate = 240 },
	[10] = { .idx = 6, .rate = 120 },  [11] = { .idx = 4, .rate = 60 },
	[12] = { .idx = 11, .rate = 540 }, [13] = { .idx = 9, .rate = 360 },
	[14] = { .idx = 7, .rate = 180 },  [15] = { .idx = 5, .rate = 90 },
};

/**
 * rwnx_machw_type - Return type (NX or HE) MAC HW is used
 *
 */
int rwnx_machw_type(uint32_t machw_version_2)
{
	uint32_t machw_um_ver_maj = (machw_version_2 >> 4) & 0x7;

	if (machw_um_ver_maj >= 4)
		return RWNX_MACHW_HE;
	else
		return RWNX_MACHW_NX;
}

/**
 * rwnx_rx_status_convert - Convert in place a legacy MPDU status from NX hardware
 * into a MPDU status formatted by HE hardware.
 *
 * @machw_type: Type of MACHW in use.
 * @status: Rx MPDU status of the received frame.
 */
void rwnx_rx_status_convert(int machw_type, struct mpdu_status *status)
{
	struct mpdu_status_nx *status_nx;

	if (machw_type == RWNX_MACHW_HE)
		return;

	status_nx = (struct mpdu_status_nx *)status;
	status->undef_err = status_nx->undef_err;

	switch (status_nx->decr_status) {
	case RWNX_RX_HD_NX_DECR_UNENC:
		status->decr_type = RWNX_RX_HD_DECR_UNENC;
		status->decr_err = 0;
		break;
	case RWNX_RX_HD_NX_DECR_ICVFAIL:
		status->decr_type = RWNX_RX_HD_DECR_WEP;
		status->decr_err = 1;
		break;
	case RWNX_RX_HD_NX_DECR_CCMPFAIL:
	case RWNX_RX_HD_NX_DECR_AMSDUDISCARD:
		status->decr_type = RWNX_RX_HD_DECR_CCMP128;
		status->decr_err = 1;
		break;
	case RWNX_RX_HD_NX_DECR_NULLKEY:
		status->decr_type = RWNX_RX_HD_DECR_NULLKEY;
		status->decr_err = 1;
		break;
	case RWNX_RX_HD_NX_DECR_WEPSUCCESS:
		status->decr_type = RWNX_RX_HD_DECR_WEP;
		status->decr_err = 0;
		break;
	case RWNX_RX_HD_NX_DECR_TKIPSUCCESS:
		status->decr_type = RWNX_RX_HD_DECR_TKIP;
		status->decr_err = 0;
		break;
	case RWNX_RX_HD_NX_DECR_CCMPSUCCESS:
		status->decr_type = RWNX_RX_HD_DECR_CCMP128;
		status->decr_err = 0;
		break;
	}
}
