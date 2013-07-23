import os
from scapy import *
from scapy.all import *

class CBR_Engine:
    # pkt_rate in pkts/second, pkt_length in bytes
    def __init__(self, engine_name, pkt_rate, pkt_length):
        self.engine_name = engine_name
        self.pkt_rate = float(pkt_rate)
        self.pkt_length = pkt_length

    def generate(self, pkt_number):
        pkts = [None]*pkt_number
        for i in range(pkt_number):
            pkts[i] = Ether(''.join('X' for i in range(self.pkt_length)))
            pkts[i].time = i/self.pkt_rate
        wrpcap(self.engine_name + '.cap', pkts)

class Poisson_Engine:
    def __init__(self, engine_name, pkt_rate, pkt_length):
        self.engine_name = engine_name
        self.pkt_rate = float(pkt_rate)
        self.pkt_length = pkt_length

    def generate(self, pkt_number):
        pkts = [None]*pkt_number
        time = 0
        for i in range(pkt_number):
            pkts[i] = Ether(''.join('X' for i in range(self.pkt_length)))
            delta = random.expovariate(self.pkt_rate)
            pkts[i].time = time + delta
            time = time + delta
        wrpcap(self.engine_name + '.cap', pkts)

class Port_Arbiter:
    def __init__(self, iface, engine_list):
        self.iface = iface
        self.engine_list = engine_list

    def merge_queues(self):
        pos = [0]*len(self.engine_list);
        pcap_list = [None]*len(self.engine_list);
        for i in range(len(self.engine_list)):
            pcap_list[i] = rdpcap(self.engine_list[i] + '.cap')
        queues_num = len(self.engine_list)
        pkts_num = sum(len(pkts) for pkts in pcap_list)
        pkts = [None]*pkts_num
        while(sum(pos)<pkts_num):
            for i in range(queues_num):
                if(pos[i] < len(pcap_list[i])):
                    queue_id = i
                    break
            for i in range(queues_num):
                if(pos[i] < len(pcap_list[i]) and pcap_list[i][pos[i]].time < pcap_list[queue_id][pos[queue_id]].time):
                    queue_id = i
            pkts[sum(pos)] = pcap_list[queue_id][pos[queue_id]]
            pos[queue_id] = pos[queue_id] + 1
        wrpcap(self.iface + '.cap', pkts)


class Rate_Limiter:
    # rate in bps
    def __init__(self, iface, rate):
        self.iface = iface
        self.rate = float(rate)
        self.limit_rate()

    def limit_rate(self):
        pkts = rdpcap(self.iface + '.cap')
        last_pkt_end_time = 0
        for pkt in pkts:
            pkt.time = max(pkt.time, last_pkt_end_time)
            last_pkt_end_time = pkt.time + len(pkt)*8/self.rate
        wrpcap(self.iface + '.cap', pkts)

if __name__=="__main__":

    cbr = CBR_Engine('cbr', 100, 20)
    cbr.generate(10)

    poisson = Poisson_Engine('poisson', 100, 20)
    poisson.generate(10)

    arbiter = Port_Arbiter('eth1', ['cbr', 'poisson'])
    arbiter.merge_queues()
    rate_limiter = Rate_Limiter('eth1', 128)
