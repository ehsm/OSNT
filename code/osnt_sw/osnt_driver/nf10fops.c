/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        nf10fops.c
 *
 *  Project:
 *        nic
 *
 *  Author:
 *        Yilong Geng
 *        Mario Flajslik
 *
 *  Description:
 *        This code creates a /dev/nf10 file that can be used to read/write
 *        AXI registers through ioctl calls. See sw/host/apps/rdaxi.c for
 *        an example of that.
 *
 *  Copyright notice:
 *        Copyright (C) 2010, 2011 The Board of Trustees of The Leland Stanford
 *                                 Junior University
 *
 *  Licence:
 *        This file is part of the NetFPGA 10G development base package.
 *
 *        This file is free code: you can redistribute it and/or modify it under
 *        the terms of the GNU Lesser General Public License version 2.1 as
 *        published by the Free Software Foundation.
 *
 *        This package is distributed in the hope that it will be useful, but
 *        WITHOUT ANY WARRANTY; without even the implied warranty of
 *        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *        Lesser General Public License for more details.
 *
 *        You should have received a copy of the GNU Lesser General Public
 *        License along with the NetFPGA source package.  If not, see
 *        http://www.gnu.org/licenses/.
 *
 */

#include "nf10fops.h"
#include <linux/device.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/pci.h>
#include <linux/sockios.h>
#include <linux/module.h>
#include <asm/uaccess.h>
#include <asm/tsc.h>
#include <linux/interrupt.h>
#include <asm/irq.h>

static dev_t devno;
static struct class *dev_class;

static int axi_wr_cnt = 0;
static DEFINE_SPINLOCK(axi_lock);

static struct file_operations nf10_fops={
    .owner = THIS_MODULE,
    .open = nf10fops_open,
    .unlocked_ioctl = nf10fops_ioctl,
    .release = nf10fops_release
};


int nf10fops_open (struct inode *n, struct file *f){
    struct nf10_card *card = (struct nf10_card *)container_of(n->i_cdev, struct nf10_card, cdev);
    f->private_data = card;
    return 0;
}


long nf10fops_ioctl (struct file *f, unsigned int cmd, unsigned long arg){
    struct nf10_card *card = (struct nf10_card *)f->private_data;
    uint64_t addr, val;
    unsigned long flags;
    int i;

    switch(cmd){

    case NF10_IOCTL_CMD_START_DMA:
        *(((uint64_t*)card->cfg_addr)+44) = 1;
        break;

    case NF10_IOCTL_CMD_STOP_DMA:
        *(((uint64_t*)card->cfg_addr)+44) = 0;
        break;

    case NF10_IOCTL_CMD_RESET_DMA:
        *(((uint64_t*)card->cfg_addr)+30) = 1;
        msleep(1);

        *(((uint64_t*)card->cfg_addr)+26) = 0; // disable RX interrupts

        // set tx/rx dne buffer address and mask
        *(((uint64_t*)card->cfg_addr)+16) = card->host_tx_dne_dma;
        *(((uint64_t*)card->cfg_addr)+17) = card->tx_dne_mask;
        *(((uint64_t*)card->cfg_addr)+18) = card->host_rx_dne_dma;
        *(((uint64_t*)card->cfg_addr)+19) = card->rx_dne_mask;

        // set host rx buffer address and mask
        *(((uint64_t*)card->cfg_addr)+41) = card->rx_buff_physical_addr;
        *(((uint64_t*)card->cfg_addr)+42) = card->rx_buff_mask;

        // init mem buffers
        card->mem_tx_dsc.wr_ptr = 0;
        card->mem_tx_dsc.rd_ptr = 0;
        atomic64_set(&card->mem_tx_dsc.cnt, 0);
        card->mem_tx_dsc.mask = card->tx_dsc_mask;
        card->mem_tx_dsc.cl_size = (card->tx_dsc_mask+1)/64;

        card->mem_tx_pkt.wr_ptr = 0;
        card->mem_tx_pkt.rd_ptr = 0;
        atomic64_set(&card->mem_tx_pkt.cnt, 0);
        card->mem_tx_pkt.mask = card->tx_pkt_mask;
        card->mem_tx_pkt.cl_size = (card->tx_pkt_mask+1)/64;

        card->mem_rx_pkt.wr_ptr = 0;
        card->mem_rx_pkt.rd_ptr = 0;
        atomic64_set(&card->mem_rx_pkt.cnt, 0);
        card->mem_rx_pkt.mask = card->rx_pkt_mask;
        card->mem_rx_pkt.cl_size = (card->rx_pkt_mask+1)/64;

        card->host_tx_dne.wr_ptr = 0;
        card->host_tx_dne.rd_ptr = 0;
        atomic64_set(&card->host_tx_dne.cnt, 0);
        card->host_tx_dne.mask = card->tx_dne_mask;
        card->host_tx_dne.cl_size = (card->tx_dne_mask+1)/64;

        card->host_rx_dne.wr_ptr = 0;
        card->host_rx_dne.rd_ptr = 0;
        atomic64_set(&card->host_rx_dne.cnt, 0);
        card->host_rx_dne.mask = card->rx_dne_mask;
        card->host_rx_dne.cl_size = (card->rx_dne_mask+1)/64;

        for(i = 0; i < card->host_tx_dne.cl_size; i++)
            *(((uint32_t*)card->host_tx_dne_ptr) + i * 16) = 0xffffffff;

        for(i = 0; i < card->host_rx_dne.cl_size; i++)
            *(((uint64_t*)card->host_rx_dne_ptr) + i * 8) = 0xffffffffffffffffULL;

        break;

    case NF10_IOCTL_CMD_SET_RX_DNE_HEAD:
        *(((uint64_t*)card->cfg_addr)+45) = arg;
        break;

    case NF10_IOCTL_CMD_SET_RX_BUFF_HEAD:
        *(((uint64_t*)card->cfg_addr)+43) = arg;
        break;

    case NF10_IOCTL_CMD_SET_RX_PKT_HEAD:
        *(((uint64_t*)card->cfg_addr)+46) = arg;
        break;

    case NF10_IOCTL_CMD_READ_STAT:
        if(copy_from_user(&addr, (uint64_t*)arg, 8)) printk(KERN_ERR "nf10: ioctl copy_from_user fail\n");
        if(addr >= 4096/8) return -EINVAL;
        val = *(((uint64_t*)card->cfg_addr) + 4096/8 + addr);
        if(copy_to_user((uint64_t*)arg, &val, 8))  printk(KERN_ERR "nf10: ioctl copy_to_user fail\n");
        break;
    case NF10_IOCTL_CMD_WRITE_REG:
        // check for write buffer overflow
        spin_lock_irqsave(&axi_lock, flags);
        if(axi_wr_cnt < 64){
            axi_wr_cnt++;
        }
        else{
            val = *(((uint64_t*)card->cfg_addr) + 130);
            if(val & 0x1){ // buffer empty
                axi_wr_cnt = 1;
            }
            else if(~(val & 0x2)){ // buffer not almost full
                axi_wr_cnt = 49;
            }
            else if(~(val & 0x4)){ // buffer not full
                axi_wr_cnt = 64;
            }
            else{ // buffer full
                msleep(1);

                val = *(((uint64_t*)card->cfg_addr) + 130);
                if(val & 0x1){
                    axi_wr_cnt = 1;
                }
                else if(~(val & 0x2)){
                    axi_wr_cnt = 49;
                }
                else if(~(val & 0x4)){
                    axi_wr_cnt = 64;
                }
                else{
                    axi_wr_cnt = 65;
                }
            }
        }
        spin_unlock_irqrestore(&axi_lock, flags);
        if(axi_wr_cnt > 64){
            printk(KERN_ERR "nf10: AXI write buffer full\n");
            return -EFAULT;
        }

        // write reg
        *(((uint64_t*)card->cfg_addr) + 128) = (uint64_t)arg;
        
        break;
    case NF10_IOCTL_CMD_WRITE_REG_PY:
        // check for write buffer overflow
        spin_lock_irqsave(&axi_lock, flags);
        if(axi_wr_cnt < 64){
            axi_wr_cnt++;
        }
        else{
            val = *(((uint64_t*)card->cfg_addr) + 130);
            if(val & 0x1){ // buffer empty
                axi_wr_cnt = 1;
            }
            else if(~(val & 0x2)){ // buffer not almost full
                axi_wr_cnt = 49;
            }
            else if(~(val & 0x4)){ // buffer not full
                axi_wr_cnt = 64;
            }
            else{ // buffer full
                msleep(1);

                val = *(((uint64_t*)card->cfg_addr) + 130);
                if(val & 0x1){
                    axi_wr_cnt = 1;
                }
                else if(~(val & 0x2)){
                    axi_wr_cnt = 49;
                }
                else if(~(val & 0x4)){
                    axi_wr_cnt = 64;
                }
                else{
                    axi_wr_cnt = 65;
                }
            }
        }
        spin_unlock_irqrestore(&axi_lock, flags);
        if(axi_wr_cnt > 64){
            printk(KERN_ERR "nf10: AXI write buffer full\n");
            return -EFAULT;
        }

        // write reg
        *(((uint64_t*)card->cfg_addr) + 128) = *((uint64_t*)arg);
        
        break;
    case NF10_IOCTL_CMD_READ_REG:
        if(copy_from_user(&addr, (uint64_t*)arg, 8)) printk(KERN_ERR "nf10: ioctl copy_from_user fail\n");
        *(((uint64_t*)card->cfg_addr) + 129) = (addr << 32);
        val = *(((uint64_t*)card->cfg_addr) + 129);
        if(copy_to_user((uint64_t*)arg, &val, 8))  printk(KERN_ERR "nf10: ioctl copy_to_user fail\n");        
        spin_lock_irqsave(&axi_lock, flags);
        axi_wr_cnt = 0;
        spin_unlock_irqrestore(&axi_lock, flags);
        break;
    default:
        printk(KERN_ERR "nf10: unknown ioctl\n");
        break;
    }
    
    return 0;
}

int nf10fops_release (struct inode *n, struct file *f){
    f->private_data = NULL;
    return 0;
}

int nf10fops_probe(struct pci_dev *pdev, struct nf10_card *card){
    int err;
    
    err = alloc_chrdev_region(&devno, 0, 1, DEVICE_NAME);
    if (err){
        printk(KERN_ERR "nf10: Error allocating chrdev\n");
        return err;
    }
    cdev_init(&card->cdev, &nf10_fops);
    card->cdev.owner = THIS_MODULE;
    card->cdev.ops = &nf10_fops;
    err = cdev_add(&card->cdev, devno, 1);
    if (err){
        printk(KERN_ERR "nf10: Error adding /dev/nf10\n");
        return err;
    }

    dev_class = class_create(THIS_MODULE, DEVICE_NAME);
    device_create(dev_class, NULL, devno, NULL, DEVICE_NAME);
    return 0;
}

int nf10fops_remove(struct pci_dev *pdev, struct nf10_card *card){
    device_destroy(dev_class, devno);
    class_unregister(dev_class);
    class_destroy(dev_class);
    cdev_del(&card->cdev);
    unregister_chrdev_region(devno, 1);
    return 0;
}
