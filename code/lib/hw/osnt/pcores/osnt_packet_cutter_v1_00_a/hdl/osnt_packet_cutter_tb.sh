################################################################################
#
#  NetFPGA-10G http://www.netfpga.org
#
#  File:
#        osnt_packet_cutter_tb.sh
#
#  Library:
#        hw/osnt/pcores/osnt_packet_cutter_v1_00_a
#
#  Module:
#        osnt_packet_cutter_tb.sh
#
#  Author:
#        Gianni Antichi
#
#  Description:
#        Mark Grindell- batch file to compile the test bench for the
#                       module, and to check it's basic functionality
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



cd $(dirname $0)
rm -rf unittest_build
mkdir  unittest_build
cd     unittest_build
fuse -incremental -prj ../osnt_packet_cutter_tb.prj -L unisims_ver -L unimacro_ver -L xilinxcorelib_ver -L ieee -o osnt_packet_cutter_tb.exe testbench
./osnt_packet_cutter_tb.exe -gui -tclbatch ../osnt_packet_cutter_tb.tcl
