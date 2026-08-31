
#include "rwnx_reg_data.h"
#include <linux/firmware.h>

#define FAILURE    0
#define SUCCESS    1

WQ_REG_DATA wq_reg_data = {0};

extern char *reg_data_file;

int store_change_bin_format(signed char *buffer, int file_size)
{
    int channels;
    int chan = 0;
    signed char *ptr = buffer;
    if(buffer == NULL)
    {
        printk("Invalid buffer\n");
        return FAILURE;
    }

    memcpy(&wq_reg_data.header, buffer, SIZEOF_U16);
    buffer += SIZEOF_U16;
    memcpy(&wq_reg_data.version, buffer, SIZEOF_U16);
    buffer += 2*SIZEOF_U16;

    if (wq_reg_data.header != 0x125c || wq_reg_data.version != 0x0001)
    {
        printk("Invalid header or version, header 0x%x, version 0x%x\n", wq_reg_data.header, wq_reg_data.version);
        return FAILURE;
    }

    memcpy(&wq_reg_data.length, buffer, SIZEOF_U16);

    buffer += SIZEOF_U16;
    channels = wq_reg_data.length /PER_CHAN_SIZE;
    printk("header 0x%x, version %d, length %d, channels %d\n", wq_reg_data.header, wq_reg_data.version, wq_reg_data.length, channels);

    if (!wq_reg_data.chan_pwr_tab) {
        wq_reg_data.chan_pwr_tab = kmalloc(wq_reg_data.length, GFP_KERNEL);
    }

    if (!wq_reg_data.chan_pwr_tab) {
        printk("Alloc mem failed\n");
        return FAILURE;
    }

    for(chan = 0; chan < channels && buffer; chan ++)
    {
        memcpy(&(wq_reg_data.chan_pwr_tab[chan].chan_num), buffer, SIZEOF_CHAN_NUM);  //get chan num
        buffer += SIZEOF_CHAN_NUM;
        memcpy(wq_reg_data.chan_pwr_tab[chan].rate_pwr_tab, buffer, PWR_TAB_LEN);  //get pwr data
        buffer += PWR_TAB_LEN;
    }

    memcpy(&(wq_reg_data.CRC32), buffer, 2*SIZEOF_CHAN_NUM);
    buffer += 2*SIZEOF_CHAN_NUM;

    if (buffer - ptr != file_size){
        printk("store file faild\n");
        return FAILURE;
    }
    return SUCCESS;
}

void free_pwr_tab_mem(void)
{
    kfree(wq_reg_data.chan_pwr_tab);
    wq_reg_data.chan_pwr_tab = NULL;

    return;
}

int get_pwr_data_from_bin_file(struct wq_core *core, char *file_name)
{
    int ret = FAILURE;
    const struct firmware *reg_fw = NULL;
    signed char *buffer = NULL;

    if (!file_name) {
        goto out;
    }

    if (request_firmware(&reg_fw, file_name, core->dev) < 0) {
        goto out;
    }

    buffer = kmalloc(reg_fw->size, GFP_KERNEL);
    if (!buffer) {
        goto out;
    }

    memcpy(buffer, reg_fw->data, reg_fw->size);

    if (store_change_bin_format(buffer, reg_fw->size)) {
        ret = SUCCESS;
    }

out:
    if (buffer) {
        kfree(buffer);
    }

    if(reg_fw) {
        release_firmware(reg_fw);
    }

    return ret;
}
