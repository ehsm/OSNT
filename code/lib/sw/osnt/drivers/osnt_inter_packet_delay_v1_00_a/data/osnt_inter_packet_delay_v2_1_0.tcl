################################################################################
#
#  NetFPGA-10G http://www.netfpga.org
#
#  File:
#        osnt_inter_packet_delay_v2_1_0.tcl
#
#  Library:
#        osnt/pcores/osnt_inter_packet_delay_v1_00_a
#
#  Author:
#        Muhammad Shahbaz
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
    xdefine_include_file $drv_handle "xparameters.h" "OSNT_INTER_PACKET_DELAY" "C_BASEADDR" "C_HIGHADDR" "Q0_RESET_OFFSET" "Q0_ENABLE_OFFSET" "Q0_USE_REGISTER_VALUE_OFFSET" "Q0_DELAY_REGISTER_VALUE_OFFSET" "Q1_RESET_OFFSET" "Q1_ENABLE_OFFSET" "Q1_USE_REGISTER_VALUE_OFFSET" "Q1_DELAY_REGISTER_VALUE_OFFSET" "Q2_RESET_OFFSET" "Q2_ENABLE_OFFSET" "Q2_USE_REGISTER_VALUE_OFFSET" "Q2_DELAY_REGISTER_VALUE_OFFSET" "Q3_RESET_OFFSET" "Q3_ENABLE_OFFSET" "Q3_USE_REGISTER_VALUE_OFFSET" "Q3_DELAY_REGISTER_VALUE_OFFSET" 
}

