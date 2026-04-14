/*
 * Copyright 2022 Morse Micro
 */

#include "morse.h"

#include <stdarg.h>

#define MORSE_CLI_CMDLINE_MAXLEN	(256)

#define MORSE_CLI_COMMAND "morse_cli"

int morse_cli(const char *ifname, const char *args_fmt, ...)
{
	int ret;
	char morse_cli_cmdline[MORSE_CLI_CMDLINE_MAXLEN];
	va_list vargs;
	char *buf;
	size_t spc;

	buf = morse_cli_cmdline;
	spc = sizeof(morse_cli_cmdline);

	if (ifname != NULL)
		ret = snprintf(buf, spc, "%s -i %s ", MORSE_CLI_COMMAND, ifname);
	else
		ret = snprintf(buf, spc, "%s ", MORSE_CLI_COMMAND);

	if (ret < 0)
		return ret;

	if (ret >= sizeof(morse_cli_cmdline))
		return -1; /* Buffer too small */

	buf += ret;
	spc -= ret;

	va_start(vargs, args_fmt);
	ret = vsnprintf(buf, spc, args_fmt, vargs);
	va_end(vargs);

	if (ret < 0)
		return ret;

	if (ret >= sizeof(morse_cli_cmdline))
		return -1; /* Buffer too small */

	wpa_printf(MSG_DEBUG, "morse: execute %s", morse_cli_cmdline);

	ret = system(morse_cli_cmdline);

	return ret;
}

int morse_set_long_sleep_enabled(const char *ifname, bool enabled)
{
	const char *operation = enabled ? "enable" : "disable";
	int ret;

	wpa_printf(MSG_INFO, "morse: %s long sleep on ifname %s", operation, ifname);

	ret = morse_cli(ifname, "long_sleep %s", operation);
	if (ret != 0)
		wpa_printf(MSG_WARNING,
			"morse: Failed to execute morse_cli to %s long sleep on ifname %s",
			operation, ifname);

	return ret;
}

int morse_set_s1g_op_class(const char *ifname, u8 opclass, u8 prim_opclass)
{
	int ret;

	ret = morse_cli(ifname, "opclass %u -l %u", opclass, prim_opclass);
	if (ret != 0)
		wpa_printf(MSG_WARNING,
			"morse: Failed to execute morse_cli to set s1g op class on ifname %s",
			ifname);

	return ret;
}

int morse_set_channel(const char *ifname, int oper_freq, int oper_chwidth, u8 prim_chwidth,
			u8 prim_1mhz_ch_idx)
{
	int ret;

	ret = morse_cli(ifname, "channel -n %d -c %d -o %d -p %u",
			prim_1mhz_ch_idx, oper_freq, oper_chwidth, prim_chwidth);
	if (ret != 0)
		wpa_printf(MSG_WARNING,
			"morse: Failed to execute morse_cli to set channel parameters on ifname %s",
			ifname);

	return ret;
}

int morse_set_ecsa_params(const char *ifname, u8 global_oper_class, u8 prim_chwidth,
				int oper_chwidth, int oper_freq, u8 prim_1mhz_ch_idx,
				u8 prim_global_op_class)
{
	int ret;

	ret = morse_cli(ifname, "ecsa_info -g %d -p %u -n %d -o %d -c %d -l %d",
				global_oper_class, prim_chwidth, prim_1mhz_ch_idx,
				oper_chwidth, oper_freq, prim_global_op_class);
	if (ret != 0)
		wpa_printf(MSG_WARNING,
			"morse: Failed to execute morse_cli to set ecsa parameters on ifname %s",
			ifname);

	return ret;
}

int morse_set_mbssid_info(const char *ifname, const char *tx_iface, u8 max_bss_index)
{
	int ret;

	ret = morse_cli(ifname, "mbssid -t %s -m %d",
				tx_iface,
				max_bss_index);

	if (ret != 0) {
		wpa_printf(MSG_WARNING,
				"morse: Failed to execute morse_cli to set MBSSID parameters on ifname %s",
				ifname);
	}
	return ret;
}

#if CONFIG_MORSE_STANDBY_MODE
void morse_standby_session_store(const char *ifname, const u8 *bssid,
					const char *standby_session_dir)
{
	int ret;

	if (!standby_session_dir)
		return;

	ret = morse_cli(ifname, "standby store -b " MACSTR " -d %s\n",
		MAC2STR(bssid), standby_session_dir);
	if (ret < 0)
		wpa_printf(MSG_WARNING,
			"morse: Failed to execute morse_cli to store standby session on ifname %s",
			ifname);
}
#endif /* CONFIG_MORSE_STANDBY_MODE */

int morse_set_keep_alive(const char *ifname, u16 bss_max_idle_period, bool as_11ah)
{
	int ret;

	ret = morse_cli(ifname, "keepalive %d%s", bss_max_idle_period, (as_11ah) ? " -a" : "");
	if (ret != 0)
		wpa_printf(MSG_WARNING,
			"morse: Failed to execute morse_cli to set bss max idle period on ifname %s",
			ifname);

	return ret;
}

int morse_twt_conf(const char *ifname, struct morse_twt *twt_config)
{
	int ret;

	ret = morse_cli(NULL, "twt conf -w %lld -d %d -c %d",
			twt_config->wake_interval_us, twt_config->wake_duration_us,
			twt_config->setup_command);

	if (ret != 0)
		wpa_printf(MSG_WARNING,
			"morse: Failed to execute morse_cli to set twt config on ifname %s",
			ifname);
	else
		wpa_printf(MSG_INFO, "TWT config set successfully");

	return ret;
}

int morse_cac_conf(const char *ifname, bool enable)
{
	int ret;

	ret = morse_cli(ifname, "cac %s", enable ? "enable" : "disable");
	if (ret != 0)
		wpa_printf(MSG_WARNING,
			"morse: Failed to execute morse_cli cac enable command on ifname %s",
			ifname);

	return ret;
}

int morse_set_mesh_config(const char *ifname, u8 *mesh_id, u8 mesh_id_len, u8 beaconless_mode,
	u8 max_plinks)
{
	int ret;
	char mesh_id_hex[SSID_MAX_LEN * 2 + 1];

	wpa_snprintf_hex(mesh_id_hex, sizeof(mesh_id_hex), mesh_id, mesh_id_len);
	wpa_printf(MSG_DEBUG, "morse: Mesh ID:%s Mesh ID hex:%s",
			wpa_ssid_txt(mesh_id, mesh_id_len), mesh_id_hex);

	ret = morse_cli(ifname, "mesh_config -m %s -b %d -p %d",
			mesh_id_hex, beaconless_mode, max_plinks);

	if (ret != 0) {
		wpa_printf(MSG_WARNING,
				"morse: Failed to execute morse_cli to set Mesh Config %s",
				ifname);
	}
	return ret;
}

int morse_mbca_conf(const char *ifname, u8 mbca_config, u8 min_beacon_gap, u8 tbtt_adj_interval,
	u8 beacon_timing_report_interval, u16 mbss_start_scan_duration)
{
	int ret;

	ret = morse_cli(ifname, "mbca -m %u -s %u -r %u -g %u -i %u", mbca_config,
		mbss_start_scan_duration, beacon_timing_report_interval, min_beacon_gap,
		tbtt_adj_interval);
	if (ret != 0)
		wpa_printf(MSG_WARNING,
			"morse: Failed to execute morse_cli mbca command on ifname %s", ifname);
	return ret;
}
