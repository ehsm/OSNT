import os
from axi import *
from time import sleep
from scapy import *
from scapy.all import *
from math import ceil
from packet_generator_nic import Poisson_Engine

DATAPATH_FREQUENCY = 160000000
PCAP_ENGINE_BASE_ADDR = "0x76000000"
INTER_PKT_DELAY_BASE_ADDR = {"nf0" : "0x76600000",
                             "nf1" : "0x76600010",
                             "nf2" : "0x76600020",
                             "nf3" : "0x76600030"}

RATE_LIMITER_BASE_ADDR = {"nf0" : "0x77e00000",
                          "nf1" : "0x77e00010",
                          "nf2" : "0x77e00020",
                          "nf3" : "0x77e00030"}

class OSNTGeneratorPcapEngine:

    def __init__(self):

        self.reset_reg_offset = "0x0"
        self.begin_replay_reg_offsets = ["0x4", "0x8", "0xC", "0x10"]
        self.replay_cnt_reg_offsets = ["0x14", "0x18", "0x1C", "0x20"]
        self.mem_addr_low_reg_offsets = ["0x24", "0x2C", "0x34", "0x3C"]
        self.mem_addr_high_reg_offsets = ["0x28", "0x30", "0x38", "0x40"]
        self.enable_reg_offsets = ["0x44", "0x48", "0x4C", "0x50"]

        # use axi.get_base_addr for better extensibility
        self.module_base_addr = PCAP_ENGINE_BASE_ADDR;

        self.reset = False
        self.begin_replay = [False, False, False, False]
        self.replay_cnt = [0, 0, 0, 0]
        self.mem_addr_low = [0, 0, 0, 0]
        self.mem_addr_high = [0, 0, 0, 0]
        self.enable = [False, False, False, False]

        self.get_reset()
        self.get_begin_replay()
        self.get_replay_cnt()
        self.get_memory_high_addr()

    def get_reset(self):
        value = rdaxi(self.reg_addr(self.reset_reg_offset))
        value = int(value, 16)
        if value == 0:
            self.reset = False
        else:
            self.reset = True

    #Reset the module. reset is boolean.
    def set_reset(self, reset):

        if(reset):
            value = 1
        else:
            value = 0

        wraxi(self.reg_addr(self.reset_reg_offset), hex(value))
        self.get_reset()

    def load_pcap(self, pcaps):

        # reset
        self.set_reset(True)
        self.set_reset(False)

        # read packets in and set memory boundary
        # TODO: check overflow
        pkts = {}
        self.mem_addr_low = [0, 0, 0, 0]
        self.mem_addr_high = [0, 0, 0, 0]
        self.enable = [False, False, False, False]
        self.begin_replay = [False, False, False, False]
        for i in range(4):
            if ('nf'+str(i)) in pcaps:
                self.enable[i] = True
                self.begin_replay[i] = True
                mem_addr_high = 0
                pkts.update({'nf'+str(i): rdpcap(pcaps['nf'+str(i)])})
                for pkt in pkts['nf'+str(i)]:
                    mem_addr_high = mem_addr_high + ceil(len(pkt)/float(32)) + 1
                self.mem_addr_high[i] = self.mem_addr_low[i] + mem_addr_high
                if i != 3:
                    self.mem_addr_low[i+1] = self.mem_addr_high[i]
            else:
                self.mem_addr_high[i] = self.mem_addr_low[i]
                if i != 3:
                    self.mem_addr_low[i+1] = self.mem_addr_high[i] 

        self.set_mem_addr_low()
        self.set_mem_addr_high()
        self.set_enable()

        # send packets
        for iface in pkts:
            for pkt in pkts[iface]:
                sendp(pkt, iface=iface, verbose=False)

        # set replay cnt
        self.set_replay_cnt()

        # set begin replay
        self.set_begin_replay()

    def get_mem_addr_low(self):
        for i in range(4):
            value = rdaxi(self.reg_addr(self.mem_addr_low_reg_offsets[i]))
            self.mem_addr_low[i] = int(value, 16)

    def set_mem_addr_low(self):
        for i in range(4):
            wraxi(self.reg_addr(self.mem_addr_low_reg_offsets[i]), hex(self.mem_addr_low[i]))
        self.get_mem_addr_low()

    def get_mem_addr_high(self):
        for i in range(4):
            value = rdaxi(self.reg_addr(self.mem_addr_high_reg_offsets[i]))
            self.mem_addr_high[i] = int(value, 16)

    def set_mem_addr_high(self):
        for i in range(4):
            wraxi(self.reg_addr(self.mem_addr_high_reg_offsets[i]), hex(self.mem_addr_high[i]))
        self.get_mem_addr_high()

    def get_replay_cnt(self):
        for i in range(4):
            replay_cnt = rdaxi(self.reg_addr(self.replay_cnt_reg_offsets[i]))
            self.replay_cnt[i] = int(replay_cnt, 16)

    #replay_cnt is an integer
    def set_replay_cnt(self):
        for i in range(4):
            wraxi(self.reg_addr(self.replay_cnt_reg_offsets[i]), hex(self.replay_cnt[i]))
        self.get_replay_cnt()

    def get_begin_replay(self):
        for i in range(4):
            value = rdaxi(self.reg_addr(self.begin_replay_reg_offsets[i]))
            value = int(value, 16)
            if value == 0:
                self.begin_replay[i] = False
            else:
                self.begin_replay[i] = True

    def set_begin_replay(self):
        for i in range(4):
            if(self.begin_replay[i]):
                value = 1
            else:
                value = 0
            wraxi(self.reg_addr(self.begin_replay_reg_offsets[i]), hex(value))
        self.get_begin_replay()

    def get_enable(self):
        for i in range(4):
            value = rdaxi(self.reg_addr(self.enable_offsets[i]))
            value = int(value, 16)
            if value == 0:
                self.enable[i] = False
            else:
                self.enable[i] = True

    def set_enable(self):
        for i in range(4):
            if(self.enable[i]):
                value = 1
            else:
                value = 0
            wraxi(self.reg_addr(self.enable_reg_offsets[i]), hex(value))
        self.get_enable()

    def reg_addr(self, offset):
        return add_hex(self.module_base_addr, offset)

    def print_status(self):
        print "To be added."

class OSNTRateLimiter:

    def __init__(self, iface):
        self.iface = iface
        self.module_base_addr = RATE_LIMITER_BASE_ADDR[iface]
        self.rate_reg_offset = "0x8"
        self.control_reg_offset = "0x4"
        self.reset_bit = 0
        self.enable_bit = 1

        self.rate = 0
        self.enable = False
        self.reset = False

        self.get_rate()
        self.get_enable()
        self.get_reset()

    # rate is stored as an integer value
    def get_rate(self):
        rate = rdaxi(self.reg_addr(self.rate_reg_offset))
        self.rate = int(rate, 16)

    # rate is an interger value
    def set_rate(self, rate):
        wraxi(self.reg_addr(self.rate_reg_offset), hex(rate))
        self.get_rate()

    def get_enable(self):
        value = rdaxi(self.reg_addr(self.control_reg_offset))
        value = int(value, 16)
        enable = get_bit(value, self.enable_bit)
        if enable == 0:
            self.enable = False
        else:
            self.enable = True

    def set_enable(self, enable):
        value = rdaxi(self.reg_addr(self.control_reg_offset))
        value = int(value, 16)
        if enable:
            value = set_bit(value, self.enable_bit)
        else:
            value = clear_bit(value, self.enable_bit)
        wraxi(self.reg_addr(self.control_reg_offset), hex(value))
        self.get_enable()

    def get_reset(self):
        value = rdaxi(self.reg_addr(self.control_reg_offset))
        value = int(value, 16)
        reset = get_bit(value, self.reset_bit)
        if reset == 0:
            self.reset = False;
        else:
            self.reset = True;

    def set_reset(self, reset):
        value = rdaxi(self.reg_addr(self.control_reg_offset))
        value = int(value, 16)
        if reset:
            value = set_bit(value, self.reset_bit)
        else:
            value = clear_bit(value, self.reset_bit)
        wraxi(self.reg_addr(self.control_reg_offset), hex(value))
        self.get_reset()

    def reg_addr(self, offset):
        return add_hex(self.module_base_addr, offset)

    def print_status(self):
        print 'iface: '+self.iface+' rate: '+str(self.rate)+' enable: '+str(self.enable)+' reset: '+str(self.reset)

class OSNTDelay:

    def __init__(self, iface):
        self.iface = iface
        self.module_base_addr = INTER_PKT_DELAY_BASE_ADDR[iface]
        self.control_reg_offset = "0x4"
        self.delay_reg_offset = "0x8"
        self.reset_bit = 0
        self.enable_bit = 1
        self.use_reg_bit = 2

        self.enable = False
        self.use_reg = False
        # The internal delay_length is in ticks (integer)
        self.delay = 0
        self.reset = False

        self.get_enable()
        self.get_use_reg()
        self.get_delay()
        self.get_reset()

    def get_enable(self):
        value = rdaxi(self.reg_addr(self.control_reg_offset))
        value = int(value, 16)
        enable = get_bit(value, self.enable_bit)
        if enable == 0:
            self.enable = False;
        else:
            self.enable = True;

    def set_enable(self, enable):
        value = rdaxi(self.reg_addr(self.control_reg_offset))
        value = int(value, 16)
        if enable:
            value = set_bit(value, self.enable_bit)
        else:
            value = clear_bit(value, self.enable_bit)
        wraxi(self.reg_addr(self.control_reg_offset), hex(value))
        self.get_enable()

    def get_use_reg(self):
        value = rdaxi(self.reg_addr(self.control_reg_offset))
        value = int(value, 16)
        use_reg = get_bit(value, self.use_reg_bit)
        if use_reg == 0:
            self.use_reg = False;
        else:
            self.use_reg = True;

    def set_use_reg(self, use_reg):
        value = rdaxi(self.reg_addr(self.control_reg_offset))
        value = int(value, 16)
        if use_reg:
            value = set_bit(value, self.use_reg_bit)
        else:
            value = clear_bit(value, self.use_reg_bit)
        wraxi(self.reg_addr(self.control_reg_offset), hex(value))
        self.get_use_reg()

    # delay is stored as an integer value
    def get_delay(self):
        delay = rdaxi(self.reg_addr(self.delay_reg_offset))
        self.delay = int(delay, 16)

    # delay is an interger value
    def set_delay(self, delay):
        wraxi(self.reg_addr(self.delay_reg_offset), hex(delay))
        self.get_delay()

    def get_reset(self):
        value = rdaxi(self.reg_addr(self.control_reg_offset))
        value = int(value, 16)
        reset = get_bit(value, self.reset_bit)
        if reset == 0:
            self.reset = False;
        else:
            self.reset = True;

    def set_reset(self, reset):
        value = rdaxi(self.reg_addr(self.control_reg_offset))
        value = int(value, 16)
        if reset:
            value = set_bit(value, self.reset_bit)
        else:
            value = clear_bit(value, self.reset_bit)
        wraxi(self.reg_addr(self.control_reg_offset), hex(value))
        self.get_reset()

    def reg_addr(self, offset):
        return add_hex(self.module_base_addr, offset)

    def print_status(self):
        print 'iface: '+self.iface+' delay: '+str(self.delay)+' enable: '+str(self.enable)+' reset: '+str(self.reset)+' use_reg: '+str(self.use_reg)



if __name__=="__main__":
    print "begin"
    rateLimiters = {}
    delays = {}
    poissonEngines = {}
    pcaps = {}

    # instantiate rate limiters and delay modules for 4 interfaces
    for i in range(4):
        # interface
        iface = 'nf'+str(i)
        # add rate limiter for that interface
        rateLimiters.update({iface : OSNTRateLimiter(iface)})
        # add delay module for that interface
        delays.update({iface : OSNTDelay(iface)})
        # generate *poisson engine* for that interface. This means 1000 pkts/second, 1500B packets
        poissonEngines.update({iface : Poisson_Engine(iface, 1000, 1500)})
        # generate some number of packets
        poissonEngines[iface].generate(2)
        # correlate generated packets with iterface
        pcaps.update({iface : iface+'.cap'})

    # here actually we are discarding the generated poission packets, just add custom pcap files here
    pcaps = {'nf0' : 'nf0.cap'#,
             #'nf1' : 'nf1.cap',
             #'nf2' : 'nf2.cap',
             #'nf3' : 'nf3.cap'
            }

    # configure rate limiters
    for iface, rl in rateLimiters.iteritems():
        rl.set_rate(0)
        rl.set_enable(True)
        rl.set_reset(False)
        rl.print_status()
        
    print ""

    # configure delay modules
    for iface, d in delays.iteritems():
        d.set_delay(0)
        d.set_enable(False)
        d.set_reset(False)
        d.set_use_reg(False)
        d.print_status()
        
    print ""

    # instantiate pcap engine
    pcap_engine = OSNTGeneratorPcapEngine()
    pcap_engine.replay_cnt = [1, 2, 3, 4]
    pcap_engine.load_pcap(pcaps)

