#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <stdint.h>
#include <signal.h>
#include <stdlib.h>
#include <pcap.h>

#define PAGE_SIZE 4096

#define NF10_IOCTL_CMD_READ_STAT (SIOCDEVPRIVATE+0)
#define NF10_IOCTL_CMD_WRITE_REG (SIOCDEVPRIVATE+1)
#define NF10_IOCTL_CMD_READ_REG (SIOCDEVPRIVATE+2)
#define NF10_IOCTL_CMD_RESET_DMA (SIOCDEVPRIVATE+3)
#define NF10_IOCTL_CMD_SET_RX_DNE_HEAD (SIOCDEVPRIVATE+4)
#define NF10_IOCTL_CMD_SET_RX_BUFF_HEAD (SIOCDEVPRIVATE+5)
#define NF10_IOCTL_CMD_SET_RX_PKT_HEAD (SIOCDEVPRIVATE+6)
#define NF10_IOCTL_CMD_START_DMA (SIOCDEVPRIVATE+7)
#define NF10_IOCTL_CMD_STOP_DMA (SIOCDEVPRIVATE+8)

int cmd_file;
int rx_dne_file;
int rx_buff_file;
pcap_t *pd;
pcap_dumper_t *pdumper;

uint64_t rx_dne_head = 0;
uint64_t rx_pkt_head = 0;
uint64_t rx_buff_head = 0;

char *rx_dne = NULL;
char *rx_buff = NULL;

void sig_handler(int signo)
{
    uint64_t v;

    if (signo == SIGINT){

        ioctl(cmd_file, NF10_IOCTL_CMD_STOP_DMA, v);
        close(cmd_file);
        close(rx_dne_file);
        close(rx_buff_file);
        pcap_close(pd);
        pcap_dump_close(pdumper);

        exit(0);
    }
}

int main ( int argc, char **argv )
{

    uint64_t v;
    uint64_t rx_int;
    uint64_t addr;
    uint64_t len;
    uint64_t port_encoded;
    uint64_t timestamp;

    int pkt_count = 0;

    uint64_t rx_dne_mask = 0x00000fffULL;
    uint64_t rx_pkt_mask = 0x0000ffffULL;
    uint64_t rx_buff_mask = 0xffffULL;

    struct pcap_pkthdr pcap_pkt_header;

    signal(SIGINT, sig_handler);

    cmd_file = open("/dev/nf10", O_RDWR);
    if(cmd_file < 0){
        perror("/dev/nf10");
        goto error_out;
    }

    rx_dne_file = open("/sys/kernel/debug/nf10_rx_dne_mmap", O_RDWR);
    if(rx_dne_file < 0) {
        perror("nf10_rx_dne_mmap");
        goto error_out;
    }

    rx_buff_file = open("/sys/kernel/debug/nf10_rx_buff_mmap", O_RDWR);
    if(rx_buff_file < 0) {
        perror("nf10_rx_buff_mmap");
        goto error_out;
    }

    rx_dne = mmap(NULL, rx_dne_mask+1, PROT_READ|PROT_WRITE, MAP_SHARED, rx_dne_file, 0);
    if (rx_dne == MAP_FAILED) {
        perror("mmap rx_dne error");
        goto error_out;
    }

    rx_buff = mmap(NULL, rx_buff_mask+1+PAGE_SIZE, PROT_READ, MAP_SHARED, rx_buff_file, 0);
    if (rx_buff == MAP_FAILED) {
        perror("mmap rx_buff error");
        goto error_out;
    }

    if(ioctl(cmd_file, NF10_IOCTL_CMD_RESET_DMA, v) < 0){
        perror("nf10 reset dma failed");
        goto error_out;
    }

    if(ioctl(cmd_file, NF10_IOCTL_CMD_START_DMA, v) < 0){
        perror("nf10 start dma failed");
        goto error_out;
    }

    pd = pcap_open_dead(DLT_RAW, 65535);
    pdumper = pcap_dump_open(pd, "packets.cap");

    while(1){
        rx_int = *(((uint64_t*)rx_dne) + rx_dne_head/8);
        if( ((rx_int >> 48) & 0xffff) != 0xffff ){

            pkt_count++;
            printf("%d packets received\n", pkt_count);

            timestamp = *(((uint64_t*)rx_dne) + (rx_dne_head)/8 + 1);
            len = rx_int & 0xffff;
            port_encoded = (rx_int >> 16) & 0xffff;

            *(((uint64_t*)rx_dne) + rx_dne_head/8) = 0xffffffffffffffffULL;


            rx_dne_head = ((rx_dne_head + 64) & rx_dne_mask);
            rx_buff_head = ((rx_buff_head + ((len-1)/64 + 1)*64) & rx_buff_mask);
            rx_pkt_head = ((rx_pkt_head + ((len-1)/64 + 1)*64) & rx_pkt_mask);

            pcap_pkt_header.ts.tv_sec = ((timestamp>>32)&0xffffffff);
            pcap_pkt_header.ts.tv_nsec = (((timestamp&0xffffffff)*1000000000)>>32);
            pcap_pkt_header.caplen = len;
            pcap_pkt_header.len = len;
            pcap_dump(pdumper, &pcap_pkt_header, rx_buff+rx_buff_head);

            if(ioctl(cmd_file, NF10_IOCTL_CMD_SET_RX_DNE_HEAD, rx_dne_head) < 0){
                perror("nf10 set rx dne head failed");
                goto error_out;
            }

            if(ioctl(cmd_file, NF10_IOCTL_CMD_SET_RX_BUFF_HEAD, rx_buff_head) < 0){
                perror("nf10 set rx buff head failed");
                goto error_out;
            }

            if(ioctl(cmd_file, NF10_IOCTL_CMD_SET_RX_PKT_HEAD, rx_pkt_head) < 0){
                perror("nf10 set rx pkt head failed");
                goto error_out;
            }
            
        }

    }

error_out:
    ioctl(cmd_file, NF10_IOCTL_CMD_STOP_DMA, v);
    close(cmd_file);
    close(rx_dne_file);
    close(rx_buff_file);
    pcap_close(pd);
    pcap_dump_close(pdumper);
    return -1;
}

