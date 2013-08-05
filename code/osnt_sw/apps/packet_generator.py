import os
from axi import *
from time import sleep
from scapy import *
from scapy.all import *

DATAPATH_FREQUENCY = 160000000

class DelayField(IntField):

    def __init__(self, name, default):
        IntField.__init__(self, name, default)

    def i2m(self, pkt, x):
        x = '{0:032b}'.format(x)
        x = x[::-1]
        x = '{0:08x}'.format(int(x, 2))
        return x.decode('hex')

    def m2i(self, pkt, x):
        x = x.encode('hex')
        x = '{0:032b}'.format(int(x, 16))
        x = x[::-1]
        return int(x, 2)

    def addfield(self, pkt, s, val):
        return s+self.i2m(pkt, val)

    def getfield(self, pkt, s):
        return s[4:], self.m2i(pkt, s[:4])

class DelayHeader(Packet):
    fields_desc = [
          DelayField("delay", 0)
          ]

class packet_generator_sram_fifo:

    def __init__(self, name):
        self.name = name
        self.queue_base_addr_offset = ["0x00", "0x01", "0x02", "0x03"]
        self.queue_bound_addr_offset = ["0x10", "0x11", "0x12", "0x13"]
        self.queue_tail_addr_offset = ["0x20", "0x21", "0x22", "0x23"]
        self.replay_times_offset = "0x30"
        self.begin_replay_offset = "0x31"
        self.host_reset_offset = "0x32"

        self.queue_base_addr = [None]*4
        self.queue_bound_addr = [None]*4
        self.queue_tail_addr = [None]*4
        self.pcap = ""

        self.module_base_addr = get_base_addr(name)
        self.get_queue_size()

    #Reset the module. reset is boolean.
    def reset(self, reset):
        if(reset):
            value = hex(1)
        else:
            value = hex(0)
        wraxi(self.reg_addr(self.host_reset_offset), value)
        sleep(0.1)

    def load_pcap(self, pcap, iface):

        pkts = rdpcap(pcap)
        time = [pkt.time for pkt in pkts]
        delay = [int((time[x+1]-time[x])*DATAPATH_FREQUENCY) for x in range(len(pkts)-1)]
        delay = [0] + delay;
        pkts = [DelayHeader(delay=delay[x])/pkts[x] for x in range(len(pkts))]

        for pkt in pkts:
            sendp(pkt, iface=iface)
        

    def get_queue_size(self):
        for i in range(4):
            self.queue_base_addr[i] = rdaxi(self.reg_addr(self.queue_base_addr_offset[i]))
            self.queue_bound_addr[i] = rdaxi(self.reg_addr(self.queue_bound_addr_offset[i]))
            self.queue_tail_addr[i] = rdaxi(self.reg_addr(self.queue_tail_addr_offset[i]))

    def resize_queue(self, base_addr, bound_addr):
        self.reset(True)
        for i in range(4):
            wraxi(self.reg_addr(self.queue_base_addr_offset[i]), base_addr[i])
            wraxi(self.reg_addr(self.queue_bound_addr_offset[i]), bound_addr[i])
        self.reset(False)
        self.get_queue_size()

    #replay_times is an integer
    def set_replay_times(self, replay_times):
        self.set_begin_replay(False)
        wraxi(self.reg_addr(self.replay_times_offset), hex(replay_times))

    def set_begin_replay(self, begin):
        if(begin):
            value = hex(1)
        else:
            value = hex(0)
        wraxi(self.reg_addr(self.begin_replay_offset), value)
        sleep(0.01)

    def reg_addr(self, offset):
        return self.add_hex(self.module_base_addr, offset)

    def add_hex(self, hex1, hex2):
        return hex(int(hex1, 16) + int(hex2, 16))

class rate_limiter:

    def __init__(self, name):
        self.name = name
        self.module_base_addr = get_base_addr(name)
        self.throughput_shift_offset = "0x00"
        self.rate_limiter_enable_offset = "0x01"
        self.host_reset_offset = "0x02"

        self.throughput_shift = 0
        self.rate_limiter_enable = False
        self.host_reset = False

        self.get_throughput_shift()
        self.get_rate_limiter_enable()
        self.get_host_reset()

    # throughput_shift is stored as an integer value
    def get_throughput_shift(self):
        throughput_shift = rdaxi(self.reg_addr(self.throughput_shift_offset))
        self.throughput_shift = int(throughput_shift, 16)

    # throughput_shift is an interger value
    def set_throughput_shift(self, throughput_shift):
        wraxi(self.reg_addr(self.throughput_shift_offset), hex(throughput_shift))
        sleep(0.01)
        self.get_throughput_shift()

    def get_rate_limiter_enable(self):
        rate_limiter_enable = rdaxi(self.reg_addr(self.rate_limiter_enable_offset))
        if int(rate_limiter_enable, 16) == 0:
            self.rate_limiter_enable = False
        else:
            self.rate_limiter_enable = True

    def set_rate_limiter_enable(self, enable):
        if enable:
            value = 1
        else:
            value = 0
        wraxi(self.reg_addr(self.rate_limiter_enable_offset), hex(value))
        sleep(0.01)
        self.get_rate_limiter_enable()

    def get_host_reset(self):
        host_reset = rdaxi(self.reg_addr(self.host_reset_offset))
        if int(host_reset, 16) == 0:
            self.host_reset = False;
        else:
            self.host_reset = True;

    def set_host_reset(self, host_reset):
        if host_reset:
            value = 1
        else:
            value = 0
        wraxi(self.reg_addr(self.host_reset_offset), hex(value))
        sleep(0.1)
        self.get_host_reset()

    def reg_addr(self, offset):
        return self.add_hex(self.module_base_addr, offset)

    def add_hex(self, hex1, hex2):
        return hex(int(hex1, 16) + int(hex2, 16))

class inter_pkt_delay:

    def __init__(self, name):
        self.name = name
        self.module_base_addr = get_base_addr(name)
        self.delay_enable_offset = "0x00"
        self.delay_use_reg_offset = "0x01"
        self.delay_length_offset = "0x02"
        self.host_reset_offset = "0x03"

        self.delay_enable = False
        self.delay_use_reg = False
        # The internal delay_length is in ticks (integer)
        self.delay_length = 0
        self.host_reset = False

        self.get_delay_enable()
        self.get_delay_use_reg()
        self.get_delay_length()
        self.get_host_reset()
        pass

    def get_delay_enable(self):
        delay_enable = rdaxi(self.reg_addr(self.delay_enable_offset))
        if int(delay_enable, 16) == 0:
            self.delay_enable = False;
        else:
            self.delay_enable = True;

    def set_delay_enable(self, delay_enable):
        if delay_enable:
            value = 1
        else:
            value = 0
        wraxi(self.reg_addr(self.delay_enable_offset), hex(value))
        sleep(0.01)
        self.get_delay_enable()

    def get_delay_use_reg(self):
        delay_use_reg = rdaxi(self.reg_addr(self.delay_use_reg_offset))
        if int(delay_use_reg, 16) == 0:
            self.delay_use_reg = False;
        else:
            self.delay_use_reg = True;

    def set_delay_use_reg(self, delay_use_reg):
        if delay_use_reg:
            value = 1
        else:
            value = 0
        wraxi(self.reg_addr(self.delay_use_reg_offset), hex(value))
        sleep(0.01)
        self.get_delay_use_reg()

    # delay_length is stored as an integer value
    def get_delay_length(self):
        delay_length = rdaxi(self.reg_addr(self.delay_length_offset))
        self.delay_length = int(delay_length, 16)

    # delay_length is an interger value
    def set_delay_length(self, delay_length):
        wraxi(self.reg_addr(self.delay_length_offset), hex(delay_length))
        sleep(0.01)
        self.get_delay_length()

    def get_host_reset(self):
        host_reset = rdaxi(self.reg_addr(self.host_reset_offset))
        if int(host_reset, 16) == 0:
            self.host_reset = False;
        else:
            self.host_reset = True;

    def set_host_reset(self, host_reset):
        if host_reset:
            value = 1
        else:
            value = 0
        wraxi(self.reg_addr(self.host_reset_offset), hex(value))
        sleep(0.1)
        self.get_host_reset()

    def reg_addr(self, offset):
        return self.add_hex(self.module_base_addr, offset)

    def add_hex(self, hex1, hex2):
        return hex(int(hex1, 16) + int(hex2, 16))

if __name__=="__main__":

    #pg = packet_generator_sram_fifo("packet_generator_sram_fifo_0")
    rl = rate_limiter("rate_limiter_1")
    d = inter_pkt_delay("delay_1")

    rl.set_host_reset(True)
    d.set_host_reset(True)
    #pg.reset(True)

    print rl.module_base_addr
    print rl.throughput_shift
    print rl.rate_limiter_enable
    print rl.host_reset
    rl.set_throughput_shift(7)
    rl.set_rate_limiter_enable(True)
    rl.set_host_reset(False)
    print rl.throughput_shift
    print rl.rate_limiter_enable
    print rl.host_reset

    print "=================="
    print d.module_base_addr
    print d.delay_enable
    print d.delay_use_reg
    print d.delay_length
    print d.host_reset
    d.set_delay_enable(False)
    d.set_delay_use_reg(True)
    d.set_delay_length(160000000)
    d.set_host_reset(False)
    print d.delay_enable
    print d.delay_use_reg
    print d.delay_length
    print d.host_reset


    """
    print "===================="
    print pg.queue_base_addr
    print pg.queue_bound_addr
    print pg.queue_tail_addr
    pg.set_begin_replay(False)
    pg.reset(False)
    pg.load_pcap("a.pcap", "nf1")
    pg.load_pcap("a.pcap", "nf1")
    sleep(1)
    pg.get_queue_size()
    print "=========="
    print pg.queue_base_addr
    print pg.queue_bound_addr
    print pg.queue_tail_addr
    pg.set_replay_times(2)
    pg.set_begin_replay(True)
    """



