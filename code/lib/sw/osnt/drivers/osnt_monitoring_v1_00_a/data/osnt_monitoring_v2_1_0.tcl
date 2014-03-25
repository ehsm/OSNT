################################################################################
#
#  NetFPGA-10G http://www.netfpga.org
#
#  File:
#        osnt_monitoring_v2_1_0.tcl
#
#  Library:
#        osnt/pcores/osnt_monitoring_v1_00_a
#
#  Author:
#        Gianni Antichi
#
#  Description:
#        Driver TCL script
#
#  Copyright notice:
#        Copyright (C) 2010, 2011 The Board of Trustees of The Leland Stanford
#                                 Junior University
#
#  Licence:
#        This file is part of the NetFPGA 10G development base package.
#
#        This file is free code: you can redistribute it and/or modify it under
#        the terms of the GNU Lesser General Public License version 2.1 as
#        published by the Free Software Foundation.
#
#        This package is distributed in the hope that it will be useful, but
#        WITHOUT ANY WARRANTY; without even the implied warranty of
#        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#        Lesser General Public License for more details.
#
#        You should have received a copy of the GNU Lesser General Public
#        License along with the NetFPGA source package.  If not, see
#        http://www.gnu.org/licenses/.
#
#


proc generate {drv_handle} {
    #---------------------------
    # #defines in xparameters.h
    #---------------------------
    xdefine_include_file $drv_handle "xparameters.h" "OSNT_MONITORING" "FILTER_TABLE_DEPTH" "C_BAR0_BASEADDR" "C_BAR0_HIGHADDR" "BAR0_STATS_RESET_OFFSET" "BAR0_STATS_FREEZE_OFFSET" "BAR0_PKT_COUNT_INTF0_OFFSET" "BAR0_PKT_COUNT_INTF1_OFFSET" "BAR0_PKT_COUNT_INTF2_OFFSET" "BAR0_PKT_COUNT_INTF3_OFFSET" "BAR0_BYTES_COUNT_INTF0_OFFSET" "BAR0_BYTES_COUNT_INTF1_OFFSET" "BAR0_BYTES_COUNT_INTF2_OFFSET" "BAR0_BYTES_COUNT_INTF3_OFFSET" "BAR0_VLAN_COUNT_INTF0_OFFSET" "BAR0_VLAN_COUNT_INTF1_OFFSET" "BAR0_VLAN_COUNT_INTF2_OFFSET" "BAR0_VLAN_COUNT_INTF3_OFFSET" "BAR0_IP_COUNT_INTF0_OFFSET" "BAR0_IP_COUNT_INTF1_OFFSET" "BAR0_IP_COUNT_INTF2_OFFSET" "BAR0_IP_COUNT_INTF3_OFFSET" "BAR0_UDP_COUNT_INTF0_OFFSET" "BAR0_UDP_COUNT_INTF1_OFFSET" "BAR0_UDP_COUNT_INTF2_OFFSET" "BAR0_UDP_COUNT_INTF3_OFFSET" "BAR0_TCP_COUNT_INTF0_OFFSET" "BAR0_TCP_COUNT_INTF1_OFFSET" "BAR0_TCP_COUNT_INTF2_OFFSET" "BAR0_TCP_COUNT_INTF3_OFFSET" "BAR0_STATS_TIME_LOW_OFFSET" "BAR0_STATS_TIME_HIGH_OFFSET" "C_BAR1_BASEADDR" "C_BAR1_HIGHADDR" "BAR1_SIP_OFFSET" "BAR1_SIP_MASK_OFFSET" "BAR1_DIP_IP_OFFSET" "BAR1_DIP_MASK_OFFSET" "BAR1_L4_PORTS_OFFSET" "BAR1_L4_PORTS_MASK_OFFSET" "BAR1_PROTO_OFFSET" "BAR1_PROTO_MASK_OFFSET" "BAR1_WR_ADDR_OFFSET" "BAR1_RD_ADDR_OFFSET" }

