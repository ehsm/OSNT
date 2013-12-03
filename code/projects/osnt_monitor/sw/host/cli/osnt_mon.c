/* ****************************************************************************
 * $Id: cli.c 2013-12-03 16:09 Gianni Antichi $
 *
 * Module: osnt_mon.c
 * Project: Monitoring CLI
 * Description: Manage the Monitoring System
 *
 */


#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include <string.h>
#include <inttypes.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <stdio.h>
#include "osnt_mon.h"
#include "common/nf10util.h"


#define DEFAULT_DEV_NAME   "nf10"

/* Global vars */
int nf10;

int main(int argc, char *argv[])
{
  
  printf("***Welcome to the OSNT Monitoring Command Line Interface***\n");
  printf("type 'help' to obtain the allowed commands\n\n");

  nf10 = open("/dev/nf10", O_RDWR);

  if (nf10 < 0) {
  	printf("ERROR opening register device /dev/nf10\n");
        exit(1);
  }

  prompt();

  return 0;
}


void prompt(void) {
  while (1) { 
    printf("> ");
    char c[15];
    scanf("%s", c);
    int res = parse(c);
    switch (res) {
    case 0:
      list_rules();
      break;
    case 1:
      set_rules();
      break;
    case 2:
      clear_rules();
      break;
    case 3:
      load_rules();
      break;
    case 4:
      check_stats();
      break;
    case 5:
      reset_stats();
      break;
    case 6:
      enable_cut();
      break;
    case 7:
      disable_cut();
      break;
    case 8:
      set_ntp();
      break;
    case 9:
      reset_time();
      break;
    case 10:
      en_gps_correction();
      break;
    case 11:
      dis_gps_correction();
       break;
    case 12:
      check_gps_signal();
      break;
    case 13:
      author();
      break;
    case 14:
      help();
      break;
    case 15:
      quit();
      break;
    default:
      printf("Unknown command, type 'help' for list of commands\n");
    }
  }
}

void help(void) {
  printf("Commands:\n");
  printf("  list_rules         - Lists entries in the Filter table\n");
  printf("  set_rules          - Set an entry in the Filter table\n");
  printf("  clear_rules        - Clear a Filter table entry\n");
  printf("  load_rules         - Load Filter table entries from a file\n");

  printf("  check_stats        - Display per-port statistics\n");
  printf("  reset_stats        - Reset per-port statistics\n");
  printf("  enable_cut         - Enable the cut/hash feature\n");
  printf("  disable_cut        - Disable the cut/hash feature\n");
  printf("  set_ntp            - Initialize the HW stamp counter with the NTP value\n");
  printf("  reset_time         - Reset HW time\n");
  printf("  en_gps_correction  - Enable GPS correction\n");
  printf("  dis_gps_correction - Disable GPS correction\n");
  printf("  check_gps_signal   - Check GPS connectivity\n");

  printf("  author             - Display Author and Version\n");
  printf("  help               - Displays this list\n");
  printf("  quit               - Exit this program\n");
}

void quit(void) {
  exit(0);
}

void author(void) {
  printf("OSNT Monitoring System 1.0\n");
  printf("\tGianni Antichi @ Computer Lab (University of Cambridge)\n");
}


void addrules(int entry, int proto, uint8_t *src_ip, uint8_t *dest_ip, int l4ports, int proto_mask, uint8_t *src_ip_mask, uint8_t *dest_ip_mask, int l4ports_mask) {
  
  int err;  

  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_PROTO_REG, proto);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_PROTO_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_SRC_IP_REG, src_ip[0] << 24 | src_ip[1] << 16 | src_ip[2] << 8 | src_ip[3]);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_SRC_IP_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_DST_IP_REG, dest_ip[0] << 24 | dest_ip[1] << 16 | dest_ip[2] << 8 | dest_ip[3]);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_DST_IP_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_L4PORTS_REG, l4ports);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_L4PORTS_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_PROTO_MASK_REG, proto_mask);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_PROTO_MASK_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_SRC_IP_MASK_REG, src_ip_mask[0] << 24 | src_ip_mask[1] << 16 | src_ip_mask[2] << 8 | src_ip_mask[3]);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_SRC_IP_MASK_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_DST_IP_MASK_REG, dest_ip_mask[0] << 24 | dest_ip_mask[1] << 16 | dest_ip_mask[2] << 8 | dest_ip_mask[3]);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_DST_IP_MASK_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_L4PORTS_MASK_REG, l4ports_mask);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_L4PORTS_MASK_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_WR_ADDR_REG, entry);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_WR_ADDR_REG);
}

void set_rules(void) {
  printf("Enter [entry]  [proto]  [src ip]     [dest ip]   [l4 ports]  [proto mask] [src ip mask] [dest ip mask] [l4 ports mask]:\n");
  printf("e.g.     0       0x6   192.168.0.1  192.168.0.2  0x00a800b7      0x00     255.225.255.0 255.255.255.0        0x0      :\n");
  printf(">> ");

  char src_ip[32], dest_ip[32], src_ip_mask[32], dest_ip_mask[32];
  int proto, l4ports, proto_mask, l4ports_mask, entry;
  scanf("%i %x %s %s %x %x %s %s %x", &entry, &proto, src_ip, dest_ip, &l4ports, &proto_mask, src_ip_mask, dest_ip_mask, &l4ports_mask);

  if ((entry < 0) || (entry >= NUM_ENTRIES)) {
    printf("Entry must be between 0 and %d. Aborting\n",NUM_ENTRIES-1);
    return;
  }

  uint8_t *sr = parseip(src_ip);
  uint8_t *dr = parseip(dest_ip);
  uint8_t *sm = parseip(src_ip_mask);
  uint8_t *dm = parseip(dest_ip_mask);

  addrules(entry, proto, sr, dr, l4ports, proto_mask, sm, dm, l4ports_mask);
}


void list_rules(void) {
  int i;
  int err;
  for (i = 0; i < NUM_ENTRIES; i++) {
    unsigned prot, sip, dip, l4p, prot_m, sip_m, dip_m, l4p_m;

    err=writeReg(nf10,OSNT_MON_FILTER_TABLE_RD_ADDR_REG, i);
    if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_RD_ADDR_REG);

    err=readReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_PROTO_REG, &prot);
    if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_PROTO_REG);
    err=readReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_SRC_IP_REG, &sip);
    if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_SRC_IP_REG);
    err=readReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_DST_IP_REG, &dip);
    if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_DST_IP_REG);
    err=readReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_L4PORTS_REG, &l4p);
    if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_L4PORTS_REG);
    err=readReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_PROTO_MASK_REG, &prot_m);
    if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_PROTO_MASK_REG);
    err=readReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_SRC_IP_MASK_REG, &sip_m);
    if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_SRC_IP_MASK_REG);
    err=readReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_DST_IP_MASK_REG, &dip_m);
    if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_DST_IP_MASK_REG);
    err=readReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_L4PORTS_MASK_REG, &l4p_m);
    if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_L4PORTS_MASK_REG);

    printf("Entry #%02i:   ", i);
    int proto = prot & 0xff;
    int proto_mask = prot_m & 0xff;
    if (proto!=0 || sip!=0 || dip!=0 || l4p!=0 || proto_mask!=0xff || sip_m != 0xffffffff || dip_m != 0xffffffff || l4p_m != 0xffffffff) {
      printf("Proto: 0x%02x, ", proto);
      printf("Src IP: %i.%i.%i.%i, ", sip >> 24, (sip >> 16) & 0xff, (sip >> 8) & 0xff, sip & 0xff);
      printf("Dest IP: %i.%i.%i.%i, ", dip >> 24, (dip >> 16) & 0xff, (dip >> 8) & 0xff, dip & 0xff);
      printf("L4 Ports: %i/%i, ", l4p >> 16, l4p & 0xffff);
      printf("Proto Mask: 0x%02x, ", proto_mask);
      printf("Src IP Mask: 0x%x, ", sip_m);
      printf("Dest IP Mask: 0x%x, ", dip_m);
      printf("L4 Ports Mask: 0x%04x/0x%04x\n", l4p_m >> 16, l4p_m & 0xffff);
    }
    else {
      printf("--Invalid--\n");
    }
  }
}

void load_rules(void) {
  char fn[30];
  printf("Enter filename:\n");
  printf(">> ");
  scanf("%s", fn);

  FILE *fp;
  char sip[20], dip[20], sip_m[20], dip_m[20];
  int entry, proto, proto_m, l4ports, l4ports_m;
  if((fp = fopen(fn, "r")) ==NULL) {
    printf("Error: cannot open file %s.\n", fn);
    return;
  }
  while (fscanf(fp, "%i %x %s %s %x %x %s %s %x", &entry, &proto, sip, dip, &l4ports, &proto_m, sip_m, dip_m,  &l4ports_m) != EOF) {
    uint8_t *srcip = parseip(sip);
    uint8_t *destip = parseip(dip);
    uint8_t *srcip_m = parseip(sip_m);
    uint8_t *destip_m = parseip(dip_m);

    addrules(entry, proto, srcip, destip, l4ports, proto_m, srcip_m, destip_m, l4ports_m);
  }
}


void clear_rules(void) {
  int entry;
  printf("Specify entry:\n");
  printf(">> ");
  scanf("%i", &entry);

  int err;

  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_PROTO_REG, 0);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_PROTO_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_SRC_IP_REG, 0);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_SRC_IP_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_DST_IP_REG, 0);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_DST_IP_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_L4PORTS_REG, 0);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_L4PORTS_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_PROTO_MASK_REG, 0xff);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_PROTO_MASK_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_SRC_IP_MASK_REG, 0xffffffff);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_SRC_IP_MASK_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_DST_IP_MASK_REG, 0xffffffff);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_DST_IP_MASK_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_ENTRY_L4PORTS_MASK_REG, 0xffffffff);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_ENTRY_L4PORTS_MASK_REG);
  err=writeReg(nf10,OSNT_MON_FILTER_TABLE_WR_ADDR_REG, entry);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FILTER_TABLE_WR_ADDR_REG);

}


void check_stats(void) {

  int err;
  
  uint32_t pkt_cnt0,pkt_cnt1,pkt_cnt2,pkt_cnt3;
  uint32_t bytes_cnt0,bytes_cnt1,bytes_cnt2,bytes_cnt3;
  uint32_t vlan_cnt0,vlan_cnt1,vlan_cnt2,vlan_cnt3;
  uint32_t ip_cnt0,ip_cnt1,ip_cnt2,ip_cnt3;
  uint32_t udp_cnt0,udp_cnt1,udp_cnt2,udp_cnt3;
  uint32_t tcp_cnt0,tcp_cnt1,tcp_cnt2,tcp_cnt3;

  uint32_t time_h,time_l;
  uint64_t nanoseconds;

  err=writeReg(nf10,OSNT_MON_FREEZE_STATS, 1);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FREEZE_STATS);

  err=readReg(nf10,OSNT_MON_STATS_TIME_HIGH,&time_h);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_STATS_TIME_HIGH);
  err=readReg(nf10,OSNT_MON_STATS_TIME_LOW,&time_l);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_STATS_TIME_LOW);

  nanoseconds = (uint64_t)(((uint64_t)time_l*1000000000)>>32);

  err=readReg(nf10,OSNT_MON_PKT_CNT_0,&pkt_cnt0);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_PKT_CNT_0);
  err=readReg(nf10,OSNT_MON_BYTES_CNT_0,&bytes_cnt0);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_BYTES_CNT_0);
  err=readReg(nf10,OSNT_MON_VLAN_CNT_0,&vlan_cnt0);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_VLAN_CNT_0);
  err=readReg(nf10,OSNT_MON_IP_CNT_0,&ip_cnt0);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_IP_CNT_0);
  err=readReg(nf10,OSNT_MON_UDP_CNT_0,&udp_cnt0);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_UDP_CNT_0);
  err=readReg(nf10,OSNT_MON_TCP_CNT_0,&tcp_cnt0);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_TCP_CNT_0);

  err=readReg(nf10,OSNT_MON_PKT_CNT_1,&pkt_cnt1);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_PKT_CNT_1);
  err=readReg(nf10,OSNT_MON_BYTES_CNT_1,&bytes_cnt1);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_BYTES_CNT_1);
  err=readReg(nf10,OSNT_MON_VLAN_CNT_1,&vlan_cnt1);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_VLAN_CNT_1);
  err=readReg(nf10,OSNT_MON_IP_CNT_1,&ip_cnt1);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_IP_CNT_1);
  err=readReg(nf10,OSNT_MON_UDP_CNT_1,&udp_cnt1);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_UDP_CNT_1);
  err=readReg(nf10,OSNT_MON_TCP_CNT_1,&tcp_cnt1);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_TCP_CNT_1);

  err=readReg(nf10,OSNT_MON_PKT_CNT_2,&pkt_cnt2);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_PKT_CNT_2);
  err=readReg(nf10,OSNT_MON_BYTES_CNT_2,&bytes_cnt2);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_BYTES_CNT_2);
  err=readReg(nf10,OSNT_MON_VLAN_CNT_2,&vlan_cnt2);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_VLAN_CNT_2);
  err=readReg(nf10,OSNT_MON_IP_CNT_2,&ip_cnt2);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_IP_CNT_2);
  err=readReg(nf10,OSNT_MON_UDP_CNT_2,&udp_cnt2);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_UDP_CNT_2);
  err=readReg(nf10,OSNT_MON_TCP_CNT_2,&tcp_cnt2);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_TCP_CNT_2);

  err=readReg(nf10,OSNT_MON_PKT_CNT_3,&pkt_cnt3);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_PKT_CNT_3);
  err=readReg(nf10,OSNT_MON_BYTES_CNT_3,&bytes_cnt3);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_BYTES_CNT_3);
  err=readReg(nf10,OSNT_MON_VLAN_CNT_0,&vlan_cnt3);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_VLAN_CNT_3);
  err=readReg(nf10,OSNT_MON_IP_CNT_3,&ip_cnt3);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_IP_CNT_3);
  err=readReg(nf10,OSNT_MON_UDP_CNT_3,&udp_cnt3);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_UDP_CNT_3);
  err=readReg(nf10,OSNT_MON_TCP_CNT_3,&tcp_cnt3);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_TCP_CNT_3);

  err=writeReg(nf10,OSNT_MON_FREEZE_STATS, 0);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_FREEZE_STATS);


  printf("<----- STATISTICS ----->\n\n");
  printf("Check Time: %lu seconds %llu nanoseconds\n", time_h, nanoseconds);
  printf("Port PHY0:\n");
  printf("\t Number of Packets: 0x%08x\n",pkt_cnt0);
  printf("\t Number of Bytes: 0x%08x\n",bytes_cnt0);
  printf("\t Number of VLAN tagged Packets: 0x%08x\n",vlan_cnt0);
  printf("\t Number of IP Packets: 0x%08x\n",ip_cnt0);
  printf("\t Number of UDP Packets: 0x%08x\n",udp_cnt0);
  printf("\t Number of TCP Packets: 0x%08x\n",tcp_cnt0);
  printf("Port PHY1:\n");
  printf("\t Number of Packets: 0x%08x\n",pkt_cnt1);
  printf("\t Number of Bytes: 0x%08x\n",bytes_cnt1);
  printf("\t Number of VLAN tagged Packets: 0x%08x\n",vlan_cnt1);
  printf("\t Number of IP Packets: 0x%08x\n",ip_cnt1);
  printf("\t Number of UDP Packets: 0x%08x\n",udp_cnt1);
  printf("\t Number of TCP Packets: 0x%08x\n",tcp_cnt1);
  printf("Port PHY2:\n");
  printf("\t Number of Packets: 0x%08x\n",pkt_cnt2);
  printf("\t Number of Bytes: 0x%08x\n",bytes_cnt2);
  printf("\t Number of VLAN tagged Packets: 0x%08x\n",vlan_cnt2);
  printf("\t Number of IP Packets: 0x%08x\n",ip_cnt2);
  printf("\t Number of UDP Packets: 0x%08x\n",udp_cnt2);
  printf("\t Number of TCP Packets: 0x%08x\n",tcp_cnt2);
  printf("Port PHY3:\n");
  printf("\t Number of Packets: 0x%08x\n",pkt_cnt3);
  printf("\t Number of Bytes: 0x%08x\n",bytes_cnt3);
  printf("\t Number of VLAN tagged Packets: 0x%08x\n",vlan_cnt3);
  printf("\t Number of IP Packets: 0x%08x\n",ip_cnt3);
  printf("\t Number of UDP Packets: 0x%08x\n",udp_cnt3);
  printf("\t Number of TCP Packets: 0x%08x\n",tcp_cnt3);

}


void reset_stats(void) {

  int err;

  err=writeReg(nf10,OSNT_MON_RST_STATS, 1);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_RST_STATS);

  err=writeReg(nf10,OSNT_MON_RST_STATS, 0);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_RST_STATS);
}


void enable_cut(void){
  int err;
  int i;
  uint32_t bytes;
  uint32_t words, offset;

  uint32_t tstrb = 0xffffffff;

  printf("Please, insert how many bytes per packet you want to receive in decimal notation:\n");
  printf("\t(note that such a value will be incremented by the lenght of the hash appended at the packet\n");
  printf(">> ");

  scanf("%i", &bytes);

  if(bytes>BYTE_DATA_WIDTH){
  	words = ceil((double)((double)bytes/BYTE_DATA_WIDTH))-2;
  	offset = BYTE_DATA_WIDTH-(bytes%BYTE_DATA_WIDTH);

  	if(offset==BYTE_DATA_WIDTH)
		tstrb=0xffffffff;
  	else
		for(i=0;i<offset;i++)
			tstrb = (tstrb << 1);
 
  	printf("DEBUG: we are going to send %i words and %x tstrb and offset %i\n", words, tstrb, offset);

  	err=writeReg(nf10,OSNT_MON_CUTTER_WORDS, words);
  	if(err) printf("0x%08x: ERROR\n", OSNT_MON_CUTTER_WORDS);
  	err=writeReg(nf10,OSNT_MON_CUTTER_OFFS, tstrb);
  	if(err) printf("0x%08x: ERROR\n", OSNT_MON_CUTTER_OFFS);
  	err=writeReg(nf10,OSNT_MON_CUTTER_BYTES, bytes);
  	if(err) printf("0x%08x: ERROR\n", OSNT_MON_CUTTER_BYTES);
  	err=writeReg(nf10,OSNT_MON_CUTTER_EN, 1);
  	if(err) printf("0x%08x: ERROR\n", OSNT_MON_CUTTER_EN);


  	printf("Cut feature ENABLED!!!\n");
  }
  else
	printf("ERROR: ONLY values greater than 32 are allowed.\n");

}

void disable_cut(void){
  int err;

  
  err=writeReg(nf10,OSNT_MON_CUTTER_EN, 0);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_CUTTER_EN);


  printf("Cut feature DISABLED!!!\n");
}

void set_ntp(void){

// here we should write in the NTP registers the timestamp we want to push in HW.
// set OSNT_MON_SYNC_TIME = 2 then set again = 0.


}

void en_gps_correction(void){
  int err;

  if(check_gps_signal()) {
	err=writeReg(nf10,OSNT_MON_EN_GPS_CORRECTION, 1);
  	if(err) printf("0x%08x: ERROR\n", OSNT_MON_EN_GPS_CORRECTION);
	printf("GPS correction enabled.\n");
  }
  else 
	printf("ERROR: cannot enable GPS correction. The signal is bad or not present.\n");
}

void dis_gps_correction(void){
  int err;

  err=writeReg(nf10,OSNT_MON_EN_GPS_CORRECTION, 0);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_EN_GPS_CORRECTION);

  printf("GPS correction disabled.\n");

}


int check_gps_signal(void){
  int err;
  uint32_t gps_connected;
  unsigned char counter = 0;
  int i;

  printf("signal status");
  for(i=0;i<3;i++){
	printf(".");
	err=readReg(nf10,OSNT_MON_GPS_SIGNAL,&gps_connected);
  	if(err) printf("0x%08x: ERROR\n", OSNT_MON_GPS_SIGNAL);
	if(gps_connected) counter++;
	sleep(1);
  }

  if(counter==3){
	printf("OK!\n");
	return 1;
  }
  else if (counter==2 || counter==1){
	printf("bad signal :(\n");
	return 0;
  }
  else {
	printf("NO signal\n");
	return 0;
  }

}




void reset_time(void){
  int err;


  err=writeReg(nf10,OSNT_MON_SYNC_TIME, 1);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_SYNC_TIME);

  err=writeReg(nf10,OSNT_MON_SYNC_TIME, 0);
  if(err) printf("0x%08x: ERROR\n", OSNT_MON_SYNC_TIME);


  printf("HW time reset done.\n");
}

int parse(char *word) {
  if (!strcmp(word, "list_rules"))
    return 0;
  if (!strcmp(word, "set_rules"))
    return 1;
  if (!strcmp(word, "clear_rules"))
    return 2;
  if (!strcmp(word, "load_rules"))
    return 3;
  if (!strcmp(word, "check_stats"))
    return 4;
  if (!strcmp(word, "reset_stats"))
    return 5;
  if (!strcmp(word, "enable_cut"))
    return 6;
  if (!strcmp(word, "disable_cut"))
    return 7;
  if (!strcmp(word, "set_ntp"))
    return 8;
  if (!strcmp(word, "reset_time"))
    return 9;
  if (!strcmp(word, "en_gps_correction"))
    return 10;
  if (!strcmp(word, "dis_gps_correction"))
    return 11;
  if (!strcmp(word, "check_gps_signal"))
    return 12;
  if (!strcmp(word, "author"))
    return 13;
  if (!strcmp(word, "help"))
    return 14;
  if (!strcmp(word, "quit"))
    return 15;
  return -1;
}

uint8_t * parseip(char *str) {
  uint8_t *ret = (uint8_t *)malloc(4 * sizeof(uint8_t));
  char *num = (char *)strtok(str, ".");
  int index = 0;
  while (num != NULL) {
    ret[index++] = atoi(num);
    num = (char *)strtok(NULL, ".");
  }
  return ret;
}


