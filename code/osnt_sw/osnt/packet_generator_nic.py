import os
from scapy import *
from scapy.all import *
from subprocess import Popen, PIPE

#base timestamp of all engines is 1
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
            pkts[i].time = i/self.pkt_rate +1
        wrpcap(self.engine_name + '.cap', pkts)

class Poisson_Engine:
    def __init__(self, engine_name, pkt_rate, pkt_length):
        self.engine_name = engine_name
        self.pkt_rate = float(pkt_rate)
        self.pkt_length = pkt_length

    def generate(self, pkt_number):
        pkts = [None]*pkt_number
        time = 1
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
    # rate in bits per second
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

class Pcap_Replay:
    def __init__(self, iface):
        self.iface = iface

    def replay(self):
        proc = Popen("sudo tcpreplay -i "+self.iface+' '+self.iface+'.cap', stdout=PIPE, shell=True)
        print proc.stdout.read()

if __name__=="__main__":
    #CBR engine
    cbr = CBR_Engine('cbr', 100, 20)
    cbr.generate(10)
    #Poisson engine
    poisson = Poisson_Engine('poisson', 100, 20)
    poisson.generate(10)
    #Arbiter for port eth4
    arbiter = Port_Arbiter('eth4', ['cbr', 'poisson'])
    arbiter.merge_queues()
    #Rate limiter for port eth4
    rate_limiter = Rate_Limiter('eth4', 256)
    #Start replaying on port eth4
    replayer = Pcap_Replay('eth4')
    replayer.replay()
