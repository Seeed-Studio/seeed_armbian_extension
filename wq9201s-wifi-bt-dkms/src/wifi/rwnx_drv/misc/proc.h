#ifndef _WQ_PROC_H
#define _WQ_PROC_H

#include <linux/version.h>
#include <linux/proc_fs.h>

#if (LINUX_VERSION_CODE >= KERNEL_VERSION(5, 17, 0))
#define PDE_DATA(inode) pde_data(inode)
#endif

/* FIXME: use DEFINE_SHOW_ATTRIBUTE instead of WQ_PROC_OPS_RW */
#define WQ_PROC_OPS(_name) _name##_fops

#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 6, 0)
#define _WQ_PROC_OPS_DEF(_name) const struct file_operations WQ_PROC_OPS(_name)

#define WQ_PROC_OPS_RW(_name)                                                  \
	WQ_PROC_OPS_DEF(_name) = {                                             \
		.owner = THIS_MODULE,                                          \
		.read = _name##_read,                                          \
		.write = _name##_write,                                        \
		.llseek = noop_llseek,                                         \
	}

#else

#define _WQ_PROC_OPS_DEF(_name) const struct proc_ops WQ_PROC_OPS(_name)
#define WQ_PROC_OPS_RW(_name)                                                  \
	_WQ_PROC_OPS_DEF(_name) = {                                            \
		.proc_read = _name##_read,                                     \
		.proc_write = _name##_write,                                   \
		.proc_lseek = noop_llseek,                                     \
	}

#endif

#define WQ_PROC_DFX_CREATE(wdev, hif_names)     \
	do {  \
		struct net_device *ndev = wdev->netdev;   \
		ssize_t i;    \
		int hif_num = 0;   /* WQ_HIF_NONE remap to SDIO1/USB1 */ \
		if (!rwnx_hw->core->hif_ops->hif_proc_name) {     \
			hif_num = rwnx_hw->core->hif_ops->hif;  \
		}          \
		dfx_dir_entry[hif_num] =    \
			proc_mkdir_data(PROC_DIR#hif_names "/dfx", 0555, NULL, (void *)ndev);   \
		for (i = 0; i < sizeof(wq_dfx_hdls) / sizeof(struct kiwi_proc_dfx_hdl);  \
			 i++) {          \
			proc_create_data(wq_dfx_hdls[i].name, 0666, dfx_dir_entry[hif_num],  \
					 &kiwi_proc_dfx_fops, (void *)i);  \
		}  \
	} while(0);

#define WQ_PROC_DFX_REMOVE(hif_names)   \
	do {   \
		ssize_t i;    \
		int hif_num = 0;   /* WQ_HIF_NONE remap to SDIO1 */ \
		if (!rwnx_hw->core->hif_ops->hif_proc_name) {     \
			hif_num = rwnx_hw->core->hif_ops->hif;  \
		}              \
		for (i = 0; i < sizeof(wq_dfx_hdls) / sizeof(struct kiwi_proc_dfx_hdl);   \
			 i++) {   \
			remove_proc_entry(wq_dfx_hdls[i].name, dfx_dir_entry[hif_num]);   \
		}   \
		remove_proc_entry(PROC_DIR#hif_names "/dfx", NULL);   \
		dfx_dir_entry[hif_num] = NULL;   \
	} while(0);

#define WQ_PROC_INIT(rwnx_hw, wdev, hif)  \
	do {                                 \
		proc_mkdir(PROC_DIR#hif, NULL);   \
		proc_create_data(PROC_DIR#hif "/dbg", 0666, NULL, &kiwi_proc_fops, rwnx_hw);  \
		proc_create_data(PROC_DIR#hif "/rx_ctrl", 0666, NULL,   \
				 &kiwi_proc_rx_ctrl_fops, rwnx_hw); \
		proc_create_data(PROC_DIR#hif "/misc_ctrl", 0666, NULL,   \
				 &kiwi_proc_misc_ctrl_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/fwdbg", 0666, NULL, &kiwi_proc_fwdbg_fops,   \
				 rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/amsdu_param", S_IRUGO | S_IWUGO, NULL,   \
				 &kiwi_proc_amsdu_param_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/ampdu_param", S_IRUGO | S_IWUGO, NULL,   \
				 &kiwi_proc_ampdu_param_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/wifi_ctrl", 0666, NULL,   \
				 &kiwi_proc_wifi_ctrl_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/max_aggr_num", S_IRUGO | S_IWUGO, NULL,   \
				 &kiwi_proc_max_aggr_num_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/he_ltf_gi", S_IRUGO | S_IWUGO, NULL,   \
				 &kiwi_proc_he_ltf_gi_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/tx_mon_ctrl", S_IRUGO | S_IWUGO, NULL,   \
				 &kiwi_proc_tx_monitor_ctrl_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/amsdu_cntrl", S_IRUGO | S_IWUGO, NULL,   \
				 &kiwi_proc_amsdu_cntrl_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/debug_flag_set", S_IRUGO | S_IWUGO, NULL,   \
				 &kiwi_proc_debug_flag_set_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/param_proc", S_IRUGO | S_IWUGO, NULL,   \
				 &kiwi_proc_param_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/wifi_coex_scene", 0666, NULL,   \
				 &kiwi_proc_wifi_coex_scene_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/llrx", 0666, NULL, &proc_llrx_fops,   \
				 rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/test_mode", S_IRUGO | S_IWUGO, NULL,   \
				 &proc_test_mode_fops, wdev);   \
		proc_create_data(PROC_DIR#hif "/monitor_nbw_type", S_IRUGO | S_IWUGO, NULL,   \
				&proc_monitor_nbw_type_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/throughput", S_IRUGO, NULL,   \
				&proc_throughput_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/fw_ver", S_IRUGO, NULL,   \
				&proc_read_fw_ver_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/mon_param", S_IRUGO, NULL,   \
				&proc_read_mon_param_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/extap_ctrl", S_IRUGO | S_IWUGO, NULL,   \
				 &proc_extap_ctrl_fops, wdev);   \
		proc_create_data(PROC_DIR#hif "/peer_tx_info", S_IRUGO | S_IWUGO, NULL,   \
				 &proc_peer_tx_info_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/country_code", S_IRUGO | S_IWUGO, NULL,   \
				 &proc_country_code_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/survey_param", S_IRUGO | S_IWUGO, NULL,   \
				 &proc_survey_param_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/fw_stats_ctrl", S_IRUGO | S_IWUGO, NULL,   \
				 &proc_fw_stats_ctrl_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/fw_stats", S_IRUGO | S_IWUGO, NULL,   \
				 &proc_fw_stats_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/rssi_ant", S_IRUGO | S_IWUGO, NULL,   \
				 &proc_rssi_ant_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/timer_dump_ctrl", S_IRUGO | S_IWUGO, NULL,   \
				 &proc_timer_dump_ctrl_fops, rwnx_hw);   \
		proc_create_data(PROC_DIR#hif "/chip_reset", S_IRUGO | S_IWUGO, NULL,   \
				 &proc_chip_reset_fops, rwnx_hw);   \
		WQ_PROC_DFX_CREATE(wdev,hif);    \
	} while(0);

#define WQ_PROC_DEINIT(hif)         \
	do{                          \
		remove_proc_entry(PROC_DIR#hif "/dbg", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/rx_ctrl", NULL); \
		remove_proc_entry(PROC_DIR#hif "/misc_ctrl", NULL); \
		remove_proc_entry(PROC_DIR#hif "/fwdbg", NULL);   \
		remove_proc_entry(PROC_DIR#hif "/amsdu_param", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/ampdu_param", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/wifi_ctrl", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/max_aggr_num", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/he_ltf_gi", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/tx_mon_ctrl", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/amsdu_cntrl", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/debug_flag_set", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/param_proc", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/wifi_coex_scene", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/llrx", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/test_mode", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/monitor_nbw_type", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/extap_ctrl", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/peer_tx_info", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/throughput", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/fw_ver", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/mon_param", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/country_code", NULL);  \
		remove_proc_entry(PROC_DIR#hif "/survey_param", NULL); \
		remove_proc_entry(PROC_DIR#hif "/fw_stats_ctrl", NULL); \
		remove_proc_entry(PROC_DIR#hif "/fw_stats", NULL); \
		remove_proc_entry(PROC_DIR#hif "/rssi_ant", NULL); \
		remove_proc_entry(PROC_DIR#hif "/timer_dump_ctrl", NULL); \
		remove_proc_entry(PROC_DIR#hif "/chip_reset", NULL); \
		WQ_PROC_DFX_REMOVE(hif);  \
		remove_proc_entry(PROC_DIR#hif, NULL);  \
	}while(0);

#endif
