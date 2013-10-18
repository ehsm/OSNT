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
        self.control_reg_offset = "0x4"
        self.memory_high_addr_reg_offset = "0x8"
        self.replay_cnt_reg_offset = "0xc"
        self.reset_bit = 0
        self.begin_replay_bit = 1

        # use axi.get_base_addr for better extensibility
        self.module_base_addr = PCAP_ENGINE_BASE_ADDR;

        self.reset = False
        self.begin_replay = False
        self.replay_cnt = 0
        self.memory_high_addr = 0

        self.get_reset()
        self.get_begin_replay()
        self.get_replay_cnt()
        self.get_memory_high_addr()

    def get_reset(self):
        value = rdaxi(self.reg_addr(self.control_reg_offset))
        value = int(value, 16)
        reset = get_bit(value, self.reset_bit)
        if reset == 0:
            self.reset = False
        else:
            self.reset = True

    #Reset the module. reset is boolean.
    def set_reset(self, reset):

        value = rdaxi(self.reg_addr(self.control_reg_offset))
        value = int(value, 16)
        if(reset):
            value = set_bit(value, self.reset_bit)
        else:
            value = clear_bit(value, self.reset_bit)

        wraxi(self.reg_addr(self.control_reg_offset), hex(value))
        sleep(0.01)
        self.get_reset()

    def load_pcap(self, pcaps):
        pkts = {}
        index = {}

        finished = True

        for i in range(4):
            if ('nf'+str(i)) in pcaps:
                pkts.update({'nf'+str(i): rdpcap(pcaps['nf'+str(i)])})
                index.update({'nf'+str(i): 0})
                if len(pkts['nf'+str(i)]) > 0:
                    finished = False

        pkts_out = []

        while(not finished):
            finished = True
            tmin = float('inf')
            for iface in pkts:
                if(index[iface] < len(pkts[iface])):
                    finished = False
                    if(pkts[iface][index[iface]].time < tmin):
                        iface_tmp = iface
                        tmin = pkts[iface][index[iface]].time
            if not finished:
                pkts_out.append((iface_tmp, pkts[iface_tmp][index[iface_tmp]]))
                index[iface_tmp] = index[iface_tmp] + 1

        memory_high_addr = 0
        for pkt_out in pkts_out:
            sendp(pkt_out[1], iface=pkt_out[0], verbose=False)
            words = int(ceil(len(pkt_out[1])/16))
            memory_high_addr = memory_high_addr + words + (words%2) + 2

        self.set_memory_high_addr(memory_high_addr)

    def get_memory_high_addr(self):
        value = rdaxi(self.reg_addr(self.memory_high_addr_reg_offset))
        self.memory_high_addr = int(value, 16)

    def set_memory_high_addr(self, memory_high_addr):
        wraxi(self.reg_addr(self.memory_high_addr_reg_offset), hex(memory_high_addr))
        sleep(0.01)
        self.get_memory_high_addr()


    def get_replay_cnt(self):
        replay_cnt = rdaxi(self.reg_addr(self.replay_cnt_reg_offset))
        self.replay_cnt = int(replay_cnt, 16)

    #replay_cnt is an integer
    def set_replay_cnt(self, replay_cnt):
        wraxi(self.reg_addr(self.replay_cnt_reg_offset), hex(replay_cnt))
        sleep(0.01)
        self.get_replay_cnt()

    def get_begin_replay(self):
        value = rdaxi(self.reg_addr(self.control_reg_offset))
        value = int(value, 16)
        begin_replay = get_bit(value, self.begin_replay_bit)
        if begin_replay == 0:
            self.begin_replay = False
        else:
            self.begin_replay = True

    def set_begin_replay(self, begin):
        value = rdaxi(self.reg_addr(self.control_reg_offset))
        value = int(value, 16)
        if(begin):
            value = set_bit(value, self.begin_replay_bit)
        else:
            value = clear_bit(value, self.begin_replay_bit)
        wraxi(self.reg_addr(self.control_reg_offset), hex(value))
        sleep(0.01)
        self.get_begin_replay()

    def reg_addr(self, offset):
        return add_hex(self.module_base_addr, offset)

    def print_status(self):
        print 'pcap_engine reset: '+str(self.reset)+' begin: '+str(self.begin_replay)+' replay_cnt: '+str(self.replay_cnt)+' memory_high_addr: '+str(self.memory_high_addr)


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

    for i in range(4):
        iface = 'nf'+str(i)
        rateLimiters.update({iface : OSNTRateLimiter(iface)})
        delays.update({iface : OSNTDelay(iface)})
        poissonEngines.update({iface : Poisson_Engine(iface, 1000, 1500)})
        poissonEngines[iface].generate(10)
        pcaps.update({iface : iface+'.cap'})

    pcaps = {'nf0' : 'nf0.cap'}

    for iface, rl in rateLimiters.iteritems():
        rl.set_rate(0)
        rl.set_enable(True)
        rl.set_reset(False)
        rl.print_status()
        
    print ""

    for iface, d in delays.iteritems():
        d.set_delay(0)
        d.set_enable(False)
        d.set_reset(False)
        d.set_use_reg(False)
        d.print_status()
        
    print ""

    pcap_engine = OSNTGeneratorPcapEngine()
    pcap_engine.set_reset(False)
    pcap_engine.set_begin_replay(False)
    pcap_engine.set_replay_cnt(4)
    pcap_engine.print_status()

    pcap_engine.load_pcap(pcaps)
    pcap_engine.print_status()

    pcap_engine.set_reset(True)
    pcap_engine.set_reset(False)
    pcap_engine.set_begin_replay(True)
    pcap_engine.print_status()

    
