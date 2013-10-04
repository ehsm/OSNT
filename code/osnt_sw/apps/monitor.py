import os
from axi import *
from time import sleep
from math import *

OSNT_MON_FILTER_NUM_ENTRIES = 16
BYTE_DATA_WIDTH = 32
OSNT_MON_FILTER_BASE_ADDR = "0x72200000"
OSNT_MON_STATS_BASE_ADDR = "0x72220000"
OSNT_MON_CUTTER_BASE_ADDR = "0x77a00000"
OSNT_MON_TIMER_BASE_ADDR = "0x78a00000"

class OSNTMonitorFilter:

    def __init__(self):
        # Should use axi.get_base_addr() for extensibility.
        # Need support from .mhs file.
        self.module_base_addr = OSNT_MON_FILTER_BASE_ADDR

        self.src_ip_reg_offset = "0x0"
        self.src_ip_mask_reg_offset = "0x4"
        self.dst_ip_reg_offset = "0x8"
        self.dst_ip_mask_reg_offset = "0xc"
        self.l4ports_reg_offset = "0x10"
        self.l4ports_mask_reg_offset = "0x14"
        self.proto_reg_offset = "0x18"
        self.proto_mask_reg_offset = "0x1c"
        self.wr_addr_reg_offset = "0x20"
        self.rd_addr_reg_offset = "0x24"

        self.src_ip_table = [None] * OSNT_MON_FILTER_NUM_ENTRIES
        self.src_ip_mask_table = [None] * OSNT_MON_FILTER_NUM_ENTRIES
        self.dst_ip_table = [None] * OSNT_MON_FILTER_NUM_ENTRIES
        self.dst_ip_mask_table = [None] * OSNT_MON_FILTER_NUM_ENTRIES
        self.l4ports_table = [None] * OSNT_MON_FILTER_NUM_ENTRIES
        self.l4ports_mask_table = [None] * OSNT_MON_FILTER_NUM_ENTRIES
        self.proto_table = [None] * OSNT_MON_FILTER_NUM_ENTRIES
        self.proto_mask_table = [None] * OSNT_MON_FILTER_NUM_ENTRIES

        self.get_rules()

    #----------------------------------------
    # Basic regiter operations that do not enforce
    # synchronization between host and board.
    #----------------------------------------

    # entry is an integer from 0 to OSNT_MON_FILTER_NUM_ENTRIES - 1
    def get_rule(self, entry):

        if entry < 0 or entry >= OSNT_MON_FILTER_NUM_ENTRIES:
            return

        wraxi(self.reg_addr(self.rd_addr_reg_offset), hex(entry))
        self.src_ip_table[entry] = rdaxi(self.reg_addr(self.src_ip_reg_offset))
        self.src_ip_mask_table[entry] = rdaxi(self.reg_addr(self.src_ip_mask_reg_offset))
        self.dst_ip_table[entry] = rdaxi(self.reg_addr(self.dst_ip_reg_offset))
        self.dst_ip_mask_table[entry] = rdaxi(self.reg_addr(self.dst_ip_mask_reg_offset))
        self.l4ports_table[entry] = rdaxi(self.reg_addr(self.l4ports_reg_offset))
        self.l4ports_mask_table[entry] = rdaxi(self.reg_addr(self.l4ports_mask_reg_offset))
        self.proto_table[entry] = rdaxi(self.reg_addr(self.proto_reg_offset))
        self.proto_mask_table[entry] = rdaxi(self.reg_addr(self.proto_mask_reg_offset))

    def set_rule(self, entry):

        if entry < 0 or entry >= OSNT_MON_FILTER_NUM_ENTRIES:
            return

        wraxi(self.reg_addr(self.src_ip_reg_offset), self.src_ip_table[entry]);
        wraxi(self.reg_addr(self.src_ip_mask_reg_offset), self.src_ip_mask_table[entry])
        wraxi(self.reg_addr(self.dst_ip_reg_offset), self.dst_ip_table[entry])
        wraxi(self.reg_addr(self.dst_ip_mask_reg_offset), self.dst_ip_mask_table[entry])
        wraxi(self.reg_addr(self.l4ports_reg_offset), self.l4ports_table[entry])
        wraxi(self.reg_addr(self.l4ports_mask_reg_offset), self.l4ports_mask_table[entry])
        wraxi(self.reg_addr(self.proto_reg_offset), self.proto_table[entry])
        wraxi(self.reg_addr(self.proto_mask_reg_offset), self.proto_mask_table[entry])
        wraxi(self.reg_addr(self.wr_addr_reg_offset), hex(entry))

    def get_rules(self):

        for i in range(OSNT_MON_FILTER_NUM_ENTRIES):
            self.get_rule(i)

    def set_rules(self):

        for i in range(OSNT_MON_FILTER_NUM_ENTRIES):
            self.set_rule(i)

    #----------------------------------------
    # User operations that enforce synchronization
    # between host and board.
    #----------------------------------------

    def clear_rule(self, entry):

        if entry < 0 or entry >= OSNT_MON_FILTER_NUM_ENTRIES:
            return

        self.src_ip_table[entry] = "0x0"
        self.src_ip_mask_table[entry] = "0xffffffff"
        self.dst_ip_table[entry] = "0x0"
        self.dst_ip_mask_table[entry] = "0xffffffff"
        self.l4ports_table[entry] = "0x0"
        self.l4ports_mask_table[entry] = "0xffffffff"
        self.proto_table[entry] = "0x0"
        self.proto_mask_table[entry] = "0xff"

        self.set_rule(entry)
        self.get_rule(entry)

    def clear_rules(self):

        for i in range(OSNT_MON_FILTER_NUM_ENTRIES):
            self.clear_rule(i)

    def reg_addr(self, offset):
        return add_hex(self.module_base_addr, offset)


class OSNTMonitorStats:

    def __init__(self):
        # Should use axi.get_base_addr() for extensibility.
        # Need support from .mhs file.
        self.module_base_addr = OSNT_MON_STATS_BASE_ADDR

        self.reset_reg_offset = "0x0"
        self.freeze_reg_offset = "0x4"
        self.pkt_cnt_reg_offsets = ["0x8", "0xc", "0x10", "0x14"]
        self.byte_cnt_reg_offsets = ["0x18", "0x1c", "0x20", "0x24"]
        self.vlan_cnt_reg_offsets = ["0x28", "0x2c", "0x30", "0x34"]
        self.ip_cnt_reg_offsets = ["0x38", "0x3c", "0x40", "0x44"]
        self.udp_cnt_reg_offsets = ["0x48", "0x4c", "0x50", "0x54"]
        self.tcp_cnt_reg_offsets = ["0x58", "0x5c", "0x60", "0x64"]
        self.stats_time_low_reg_offset = "0x68"
        self.stats_time_high_reg_offset = "0x6c"

        self.pkt_cnt = [None]*4
        self.byte_cnt = [None]*4
        self.vlan_cnt = [None]*4
        self.ip_cnt = [None]*4
        self.udp_cnt = [None]*4
        self.tcp_cnt = [None]*4
        self.time_high = ""
        self.time_low = ""

        self.get_stats()


    def get_stats(self):

        wraxi(self.reg_addr(self.freeze_reg_offset), hex(1))
        for i in range(4):
            self.pkt_cnt[i] = rdaxi(self.reg_addr(self.pkt_cnt_reg_offsets[i]))
            self.byte_cnt[i] = rdaxi(self.reg_addr(self.byte_cnt_reg_offsets[i]))
            self.vlan_cnt[i] = rdaxi(self.reg_addr(self.vlan_cnt_reg_offsets[i]))
            self.ip_cnt[i] = rdaxi(self.reg_addr(self.ip_cnt_reg_offsets[i]))
            self.udp_cnt[i] = rdaxi(self.reg_addr(self.udp_cnt_reg_offsets[i]))
            self.tcp_cnt[i] = rdaxi(self.reg_addr(self.tcp_cnt_reg_offsets[i]))
        wraxi(self.reg_addr(self.freeze_reg_offset), hex(0))

        self.time_high = rdaxi(self.reg_addr(self.stats_time_high_reg_offset))
        self.time_low = rdaxi(self.reg_addr(self.stats_time_low_reg_offset))

    def reset(self):

        wraxi(self.reg_addr(self.reset_reg_offset), hex(1))
        wraxi(self.reg_addr(self.reset_reg_offset), hex(0))
        self.get_stats()

    def reg_addr(self, offset):
        return add_hex(self.module_base_addr, offset)

class OSNTMonitorCutter:

    def __init__(self):
        # Should use axi.get_base_addr() for extensibility.
        # Need support from .mhs file.
        self.module_base_addr = OSNT_MON_CUTTER_BASE_ADDR

        self.en_reg_offset = "0x0"
        self.words_reg_offset = "0x4"
        self.offs_reg_offset = "0x8"
        self.bytes_reg_offset = "0xc"

    def enable_cut(self, bytes):
        if bytes <= BYTE_DATA_WIDTH:
            return

        words = hex(int(ceil(float(bytes)/BYTE_DATA_WIDTH)) - 2)
        offset = BYTE_DATA_WIDTH - (bytes % BYTE_DATA_WIDTH)
        tstrb = hex((int("0xffffffff", 16) << offset) & int("0xffffffff", 16))

        wraxi(self.reg_addr(self.words_reg_offset), words)
        wraxi(self.reg_addr(self.offs_reg_offset), tstrb)
        wraxi(self.reg_addr(self.bytes_reg_offset), hex(bytes))
        wraxi(self.reg_addr(self.en_reg_offset), hex(1))
        return

    def disable_cut(self):
        wraxi(self.reg_addr(self.en_reg_offset), hex(0))


    def reg_addr(self, offset):
        return add_hex(self.module_base_addr, offset)

class OSNTMonitorTimer:

    def __init__(self):
        # Should use axi.get_base_addr() for extensibility.
        # Need support from .mhs file.
        self.module_base_addr = OSNT_MON_TIMER_BASE_ADDR

        self.sync_time_reg_offset = "0x0"
        self.ntp_time_low_reg_offset = "0x4"
        self.ntp_time_high_reg_offset = "0x8"

    def set_ntp(self):
        return

    def reset_time(self):
        wraxi(self.reg_addr(self.sync_time_reg_offset), hex(1))
        wraxi(self.reg_addr(self.sync_time_reg_offset), hex(0))

    def reg_addr(self, offset):
        return add_hex(self.module_base_addr, offset)
