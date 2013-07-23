#! /usr/bin/env python
import os
from fcntl import *
from struct import *

SIOCDEVPRIVATE = 35312
NF10_IOCTL_CMD_READ_STAT = SIOCDEVPRIVATE + 0
NF10_IOCTL_CMD_WRITE_REG = SIOCDEVPRIVATE + 1
NF10_IOCTL_CMD_READ_REG = SIOCDEVPRIVATE + 2

def rdaxi(addr):

    f = open("/dev/nf10", "r+")
    arg = pack("q", int(addr, 16))
    value = ioctl(f, NF10_IOCTL_CMD_READ_REG, arg)
    value = unpack("q", value)
    value = value[0]
    value = hex(value & int("0xffffffff", 16))
    f.close()
    return value

def wraxi(addr, value):

    f = open("/dev/nf10", "r+")
    arg = (int(addr, 16) << 32) + int(value, 16)
    arg = pack("q", arg)
    ioctl(f, NF10_IOCTL_CMD_WRITE_REG, arg)
    f.close()

def get_base_addr(module_name, path="../../../hw/system.mhs"):

    in_module = False
    with open(path, 'r') as f:
        for line in f:
            if(line.find("INSTANCE") != -1 and line.find(module_name) != -1):
                in_module = True
            if(in_module and line.find("END") != -1):
                in_module = False
                break
            if(in_module and line.find("C_BASEADDR") != -1):
                return line[line.find("0x"):-1]
    return ""
