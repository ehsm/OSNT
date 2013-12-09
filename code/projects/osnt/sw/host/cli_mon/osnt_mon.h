/* ****************************************************************************
 * $Id: cli.c 2012-05-05 16:09 Gianni Antichi $
 *
 * Module: monitoring.h
 * Project: Monitoring CLI
 * Description: header file
 *
 */

#define NUM_ENTRIES 					16
#define BYTE_DATA_WIDTH					32

#define OSNT_MON_FILTER_TABLE_ENTRY_SRC_IP_REG        	0x72200000
#define OSNT_MON_FILTER_TABLE_ENTRY_SRC_IP_MASK_REG	0x72200004
#define OSNT_MON_FILTER_TABLE_ENTRY_DST_IP_REG        	0x72200008
#define OSNT_MON_FILTER_TABLE_ENTRY_DST_IP_MASK_REG   	0x7220000c
#define OSNT_MON_FILTER_TABLE_ENTRY_L4PORTS_REG       	0x72200010
#define OSNT_MON_FILTER_TABLE_ENTRY_L4PORTS_MASK_REG  	0x72200014
#define OSNT_MON_FILTER_TABLE_ENTRY_PROTO_REG         	0x72200018
#define OSNT_MON_FILTER_TABLE_ENTRY_PROTO_MASK_REG    	0x7220001c

#define OSNT_MON_FILTER_TABLE_WR_ADDR_REG             	0x72200020
#define OSNT_MON_FILTER_TABLE_RD_ADDR_REG             	0x72200024

#define OSNT_MON_RST_STATS				0x72220000
#define OSNT_MON_FREEZE_STATS                           0x72220004
#define OSNT_MON_PKT_CNT_0                              0x72220008
#define OSNT_MON_PKT_CNT_1                              0x7222000c
#define OSNT_MON_PKT_CNT_2                              0x72220010
#define OSNT_MON_PKT_CNT_3                              0x72220014
#define OSNT_MON_BYTES_CNT_0                            0x72220018
#define OSNT_MON_BYTES_CNT_1                            0x7222001c
#define OSNT_MON_BYTES_CNT_2                            0x72220020
#define OSNT_MON_BYTES_CNT_3                            0x72220024
#define OSNT_MON_VLAN_CNT_0                             0x72220028
#define OSNT_MON_VLAN_CNT_1                             0x7222002c
#define OSNT_MON_VLAN_CNT_2                             0x72220030
#define OSNT_MON_VLAN_CNT_3                             0x72220034
#define OSNT_MON_IP_CNT_0                               0x72220038
#define OSNT_MON_IP_CNT_1                               0x7222003c
#define OSNT_MON_IP_CNT_2                               0x72220040
#define OSNT_MON_IP_CNT_3                               0x72220044
#define OSNT_MON_UDP_CNT_0                              0x72220048
#define OSNT_MON_UDP_CNT_1                              0x7222004c
#define OSNT_MON_UDP_CNT_2                              0x72220050
#define OSNT_MON_UDP_CNT_3                              0x72220054
#define OSNT_MON_TCP_CNT_0                              0x72220058
#define OSNT_MON_TCP_CNT_1                              0x7222005c
#define OSNT_MON_TCP_CNT_2                              0x72220060
#define OSNT_MON_TCP_CNT_3                              0x72220064
#define OSNT_MON_STATS_TIME_LOW                         0x72220068
#define OSNT_MON_STATS_TIME_HIGH                        0x7222006c

#define OSNT_MON_CUTTER_EN                              0x77a00000
#define OSNT_MON_CUTTER_WORDS                           0x77a00004
#define OSNT_MON_CUTTER_OFFS                           	0x77a00008
#define OSNT_MON_CUTTER_BYTES                           0x77a0000c

#define OSNT_MON_SYNC_TIME                           	0x78a00000
#define OSNT_MON_EN_GPS_CORRECTION                   	0x78a00004
#define OSNT_MON_NTP_TIME_LOW                           0x78a00008
#define OSNT_MON_NTP_TIME_HIGH                          0x78a0000c
#define OSNT_MON_GPS_SIGNAL                          	0x78a00010


void prompt     (void);
void help       (void);
void usage	(void);

int  parse      (char*);

void list_rules (void);
void set_rules  (void);
void clear_rules(void);
void load_rules (void);

void check_stats(void);
void reset_stats(void);
void enable_cut (void);
void disable_cut(void);

void set_ntp	(void);
void reset_time (void);
void en_gps_correction(void);
void dis_gps_correction(void);
int  check_gps_signal(void);

void author     (void);
void quit	(void);

uint8_t *parseip(char *str);
