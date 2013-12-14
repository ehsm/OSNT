import os
from axi import *
from time import sleep
from scapy import *
from scapy.all import *
from math import ceil
#from packet_generator_nic import Poisson_Engine
from subprocess import Popen, PIPE

DATAPATH_FREQUENCY = 160000000
MEM_HIGH_ADDR = 512*1024
PCAP_ENGINE_BASE_ADDR = "0x76000000"
INTER_PKT_DELAY_BASE_ADDR = {"nf0" : "0x76600000",
                             "nf1" : "0x76600010",
                             "nf2" : "0x76600020",
                             "nf3" : "0x76600030"}

RATE_LIMITER_BASE_ADDR = {"nf0" : "0x77e00000",
                          "nf1" : "0x77e0000C",
                          "nf2" : "0x77e00018",
                          "nf3" : "0x77e00024"}

DELAY_HEADER_EXTRACTOR_BASE_ADDR = "0x76e00000"

class DelayField(LongField):

    def __init__(self, name, default):
        LongField.__init__(self, name, default)

    def i2m(self, pkt, x):
        x = '{0:016x}'.format(x)
        x = x.decode('hex')
        x = x[::-1]
        x = x + ('00'*(32-8)).decode('hex')
        return x

    def m2i(self, pkt, x):
        x = x[:8]
        x = x[::-1]
        x = x.encode('hex')
        return int(x, 16)

    def addfield(self, pkt, s, val):
        return s+self.i2m(pkt, val)

    def getfield(self, pkt, s):
        return s[32:], self.m2i(pkt, s[:32])

class DelayHeader(Packet):
    fields_desc = [
          DelayField("delay", 0)
          ]

class OSNTDelayHeaderExtractor:

    def __init__(self):
        self.module_base_addr = DELAY_HEADER_EXTRACTOR_BASE_ADDR

        self.reset_reg_offset = "0x0"
        self.enable_reg_offset = "0x4"

        self.enable = False
        self.reset = False

        self.get_enable()
        self.get_reset()

    def get_status(self):
        return 'OSNTDelayHeaderExtractor: Enable: '+str(self.enable)+' Reset: '+str(self.reset)

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

    def get_enable(self):
        value = rdaxi(self.reg_addr(self.enable_reg_offset))
        value = int(value, 16)
        if value == 0:
            self.enable = False
        else:
            self.enable = True

    def set_enable(self, enable):
        if enable:
            value = 1
        else:
            value = 0
        wraxi(self.reg_addr(self.enable_reg_offset), hex(value))
        self.get_enable()

    def reg_addr(self, offset):
        return add_hex(self.module_base_addr, offset)

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
        self.get_mem_addr_low()
        self.get_mem_addr_high()
        self.get_enable()
        
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

    def clear(self):
        # reset
        self.set_reset(True)

        self.mem_addr_low = [0, 0, 0, 0]
        self.mem_addr_high = [0, 0, 0, 0]
        self.enable = [False, False, False, False]
        self.begin_replay = [False, False, False, False]
        self.replay_cnt = [0, 0, 0, 0]

        self.set_mem_addr_low()
        self.set_mem_addr_high()
        self.set_enable()
        self.set_begin_replay()
        self.set_replay_cnt()

        self.set_reset(False)

    def load_pcap(self, pcaps):

        # reset
        self.set_reset(True)

        # read packets in and set memory boundary
        # check overflow
        pkts = {}
        self.mem_addr_low = [0, 0, 0, 0]
        self.mem_addr_high = [0, 0, 0, 0]
        self.enable = [False, False, False, False]
        self.begin_replay = [False, False, False, False]

        self.set_mem_addr_low()
        self.set_mem_addr_high()
        self.set_enable()
        self.set_begin_replay()

        self.set_reset(False)

        pkts_loaded = {}
        for i in range(4):
            iface = 'nf'+str(i)
            if ('nf'+str(i)) in pcaps:
                self.enable[i] = True
                self.begin_replay[i] = True
                mem_addr_high = self.mem_addr_low[i]
                pkts.update({'nf'+str(i): rdpcap(pcaps['nf'+str(i)])})
                pkts_loaded[iface] = 0
                for pkt in pkts['nf'+str(i)]:
                    mem_addr_high_nxt = mem_addr_high + ceil(len(pkt)/float(32)) + 1
                    if mem_addr_high_nxt >= MEM_HIGH_ADDR:
                        break
                    pkts_loaded[iface] = pkts_loaded[iface] + 1
                    mem_addr_high = mem_addr_high_nxt
                self.mem_addr_high[i] = mem_addr_high
                if i != 3:
                    self.mem_addr_low[i+1] = self.mem_addr_high[i]
            else:
                self.mem_addr_high[i] = self.mem_addr_low[i]
                if i != 3:
                    self.mem_addr_low[i+1] = self.mem_addr_high[i] 

        self.set_mem_addr_low()
        self.set_mem_addr_high()
        sleep(0.1)

        self.set_enable()
        sleep(0.1)
        
        average_pkt_len = {}
        average_word_cnt = {}
        # load packets
        for iface in pkts:
            #time = [pkt.time for pkt in pkts[iface]]
            #delay = [int((time[i+1]-time[i])*DATAPATH_FREQUENCY) for i in range(len(time)-1)]
            #delay = [0] + delay
            average_pkt_len[iface] = 0
            average_word_cnt[iface] = 0
            for i in range(min(len(pkts[iface]), pkts_loaded[iface])):
                pkt = pkts[iface][i]
                average_pkt_len[iface] = average_pkt_len[iface] + len(pkt)
                average_word_cnt[iface] = average_word_cnt[iface] + ceil(len(pkt)/32.0)
                sendp(pkt, iface=iface, verbose=False)
            average_pkt_len[iface] = float(average_pkt_len[iface])/len(pkts[iface])
            average_word_cnt[iface] = float(average_word_cnt[iface])/len(pkts[iface])
        sleep(0.1)

        return {'average_pkt_len':average_pkt_len, 'average_word_cnt':average_word_cnt, 'pkts_loaded':pkts_loaded}

    def stop_replay(self):
        self.begin_replay = [False, False, False, False]
        self.set_begin_replay()

    def get_mem_addr_low(self):
        for i in range(4):
            value = rdaxi(self.reg_addr(self.mem_addr_low_reg_offsets[i]))
            self.mem_addr_low[i] = int(value, 16)

    def set_mem_addr_low(self):
        for i in range(4):
            wraxi(self.reg_addr(self.mem_addr_low_reg_offsets[i]), hex(int(self.mem_addr_low[i])))
        self.get_mem_addr_low()

    def get_mem_addr_high(self):
        for i in range(4):
            value = rdaxi(self.reg_addr(self.mem_addr_high_reg_offsets[i]))
            self.mem_addr_high[i] = int(value, 16)

    def set_mem_addr_high(self):
        for i in range(4):
            wraxi(self.reg_addr(self.mem_addr_high_reg_offsets[i]), hex(int(self.mem_addr_high[i])))
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
            value = rdaxi(self.reg_addr(self.enable_reg_offsets[i]))
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
        self.reset_reg_offset = "0x0"
        self.enable_reg_offset = "0x4"

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

    def to_string(self, average_pkt_len, average_word_cnt):
        rate = float(1)/((1<<self.rate)+1)*(average_pkt_len + 4)*8*DATAPATH_FREQUENCY/average_word_cnt
        rate_max = float(10000000000)*(average_pkt_len*8+32)/(average_pkt_len*8+32+96+64)
        rate = float(min(rate_max, rate))
        percentage = float(rate)/rate_max*100
        percentage = '{0:.4f}'.format(percentage)+'%'
        if rate >= 1000000000:
            rate = rate/1000000000
            return '{0:.2f}'.format(rate)+'Gbps '+percentage
        elif rate >= 1000000:
            rate = rate/1000000
            return '{0:.2f}'.format(rate)+'Mbps '+percentage
        elif rate >= 1000:
            rate = rate/1000
            return '{0:.2f}'.format(rate)+'Kbps '+percentage
        else:
            return '{0:.2f}'.format(rate)+'bps '+percentage

    # rate is an interger value
    def set_rate(self, rate):
        wraxi(self.reg_addr(self.rate_reg_offset), hex(rate))
        self.get_rate()

    def get_enable(self):
        value = rdaxi(self.reg_addr(self.enable_reg_offset))
        value = int(value, 16)
        if value == 0:
            self.enable = False
        else:
            self.enable = True

    def set_enable(self, enable):
        if enable:
            value = 1
        else:
            value = 0
        wraxi(self.reg_addr(self.enable_reg_offset), hex(value))
        self.get_enable()

    def get_reset(self):
        value = rdaxi(self.reg_addr(self.reset_reg_offset))
        value = int(value, 16)
        if value == 0:
            self.reset = False;
        else:
            self.reset = True;

    def set_reset(self, reset):
        if reset:
            value = 1
        else:
            value = 0
        wraxi(self.reg_addr(self.reset_reg_offset), hex(value))
        self.get_reset()
        self.set_rate(0)
        self.set_enable(False)

    def reg_addr(self, offset):
        return add_hex(self.module_base_addr, offset)

    def print_status(self):
        print 'iface: '+self.iface+' rate: '+str(self.rate)+' enable: '+str(self.enable)+' reset: '+str(self.reset)

class OSNTDelay:

    def __init__(self, iface):
        self.iface = iface
        self.module_base_addr = INTER_PKT_DELAY_BASE_ADDR[iface]
        self.delay_reg_offset = "0xc"
        self.reset_reg_offset = "0x0"
        self.enable_reg_offset = "0x4"
        self.use_reg_reg_offset = "0x8"

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
        value = rdaxi(self.reg_addr(self.enable_reg_offset))
        value = int(value, 16)
        if value == 0:
            self.enable = False;
        else:
            self.enable = True;

    def set_enable(self, enable):
        if enable:
            value = 1
        else:
            value = 0
        wraxi(self.reg_addr(self.enable_reg_offset), hex(value))
        self.get_enable()

    def get_use_reg(self):
        value = rdaxi(self.reg_addr(self.use_reg_reg_offset))
        value = int(value, 16)
        if value == 0:
            self.use_reg = False;
        else:
            self.use_reg = True;

    def set_use_reg(self, use_reg):
        if use_reg:
            value = 1
        else:
            value = 0
        wraxi(self.reg_addr(self.use_reg_reg_offset), hex(value))
        self.get_use_reg()

    # delay is stored as an integer value
    def get_delay(self):
        delay = rdaxi(self.reg_addr(self.delay_reg_offset))
        self.delay = int(delay, 16)

    def to_string(self):
        return '{:,}'.format(int(self.delay*1000000000/DATAPATH_FREQUENCY))+'ns'

    # delay is an interger value
    def set_delay(self, delay):
        wraxi(self.reg_addr(self.delay_reg_offset), hex(delay*DATAPATH_FREQUENCY/1000000000))
        self.get_delay()

    def get_reset(self):
        value = rdaxi(self.reg_addr(self.reset_reg_offset))
        value = int(value, 16)
        if value == 0:
            self.reset = False;
        else:
            self.reset = True;

    def set_reset(self, reset):
        if reset:
            value = 1
        else:
            value = 0
        wraxi(self.reg_addr(self.reset_reg_offset), hex(value))
        self.get_reset()
        self.set_enable(False)
        self.set_delay(0)
        self.set_use_reg(False)

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
    """
    # instantiate rate limiters and delay modules for 4 interfaces
    for i in range(4):
        # interface
        iface = 'nf'+str(i)
        # add rate limiter for that interface
        rateLimiters.update({iface : OSNTRateLimiter(iface)})
        # add delay module for that interface
        delays.update({iface : OSNTDelay(iface)})
        # generate *poisson engine* for that interface. This means 1000 pkts/second, 1500B packets
        #poissonEngines.update({iface : Poisson_Engine(iface, 1000, 1500)})
        # generate some number of packets
        #poissonEngines[iface].generate(2)
        # correlate generated packets with iterface
        #pcaps.update({iface : iface+'.cap'})
    """
    # here actually we are discarding the generated poission packets, just add custom pcap files here
    pcaps = {'nf0' : 'nf0.cap'#,
             #'nf1' : 'nf1.cap',
             #'nf2' : 'nf2.cap',
             #'nf3' : 'nf3.cap'
            }
    """
    # configure rate limiters
    for iface, rl in rateLimiters.iteritems():
        rl.set_rate(0)
        rl.set_enable(False)
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

    # instantiate delay header extractor
    delay_header_extractor = OSNTDelayHeaderExtractor()
    delay_header_extractor.set_reset(False)
    delay_header_extractor.set_enable(True)
    """
    # instantiate pcap engine
    pcap_engine = OSNTGeneratorPcapEngine()
    #sleep(1)
    pcap_engine.replay_cnt = [1, 2, 3, 4]
    #pcap_engine.load_pcap(pcaps)

