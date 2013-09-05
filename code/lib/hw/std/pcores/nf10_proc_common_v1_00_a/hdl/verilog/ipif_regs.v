/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        ipif_regs.v
 *
 *  Library:
 *        std/pcores/nf10_proc_common_v1_00_a
 *
 *  Module:
 *        ipif_regs
 *
 *  Author:
 *        Muhammad Shahbaz
 *
 *  Description:
 *
 *
 *  Copyright notice:
 *        Copyright (C) 2010, 2011 The Board of Trustees of The Leland Stanford
 *                                 Junior University
 *
 *  Licence:
 *        This file is part of the NetFPGA 10G development base package.
 *
 *        This file is free code: you can redistribute it and/or modify it under
 *        the terms of the GNU Lesser General Public License version 2.1 as
 *        published by the Free Software Foundation.
 *
 *        This package is distributed in the hope that it will be useful, but
 *        WITHOUT ANY WARRANTY; without even the implied warranty of
 *        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *        Lesser General Public License for more details.
 *
 *        You should have received a copy of the GNU Lesser General Public
 *        License along with the NetFPGA source package.  If not, see
 *        http://www.gnu.org/licenses/.
 *
 */

 module ipif_regs
 #(
   parameter C_S_AXI_DATA_WIDTH = 32,
   parameter C_S_AXI_ADDR_WIDTH = 32,
   parameter NUM_WO_REGS = 0, // Number of registers written by software and read by hardware only
   parameter NUM_RW_REGS = 0, // Number of registers written by software and read by both hardware and software
   parameter NUM_RO_REGS = 0  // Number of registers written by hardware and read by software only
   // Address Mapping
   //  ------  = base_address
   // |  WO  |
   // |------|         |
   // |  RW  |         |
   // |------|         \/
   // |  RO  |
   //  ------  = high_address
 )
 (
   // -- IPIF ports
   input                                               bus2ip_clk,
   input                                               bus2ip_resetn,
   input      [C_S_AXI_ADDR_WIDTH-1 : 0]               bus2ip_addr,
   input                                               bus2ip_cs,
   input                                               bus2ip_rnw,
   input      [C_S_AXI_DATA_WIDTH-1 : 0]               bus2ip_data,
   input      [C_S_AXI_DATA_WIDTH/8-1 : 0]             bus2ip_be,
   output     reg [C_S_AXI_DATA_WIDTH-1 : 0]           ip2bus_data,
   output     reg                                      ip2bus_rdack,
   output     reg                                      ip2bus_wrack,
   output                                              ip2bus_error,

   // -- Register ports
   output    [NUM_WO_REGS*C_S_AXI_DATA_WIDTH : 0]      wo_regs,
   input     [NUM_WO_REGS*C_S_AXI_DATA_WIDTH : 0]      wo_defaults,
   output    [NUM_RW_REGS*C_S_AXI_DATA_WIDTH : 0]      rw_regs,
   input     [NUM_RW_REGS*C_S_AXI_DATA_WIDTH : 0]      rw_defaults,
   input     [NUM_RO_REGS*C_S_AXI_DATA_WIDTH : 0]      ro_regs
 );

    function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction

   // -- internal parameters
   localparam addr_width = log2(NUM_WO_REGS+NUM_RW_REGS+NUM_RO_REGS);
   localparam addr_width_lsb = log2(C_S_AXI_ADDR_WIDTH/8);
   localparam addr_width_msb = addr_width+addr_width_lsb;

   // -- interal wire/regs
   genvar i;
   integer j;

   wire [C_S_AXI_DATA_WIDTH-1 : 0] reg_file_rd_port  [0 : NUM_RW_REGS+NUM_RO_REGS-1];
   reg  [C_S_AXI_DATA_WIDTH-1 : 0] reg_file_wr_port  [0 : NUM_WO_REGS+NUM_RW_REGS-1];
   wire [C_S_AXI_DATA_WIDTH-1 : 0] reg_file_defaults [0 : NUM_WO_REGS+NUM_RW_REGS-1];

   generate
	 // Unpacking Write Only registers
	 if (NUM_WO_REGS > 0)
	   for (i=0; i<NUM_WO_REGS; i=i+1) begin : WO
	     assign wo_regs[C_S_AXI_DATA_WIDTH*(i+1)-1 : C_S_AXI_DATA_WIDTH*i] = reg_file_wr_port[i];
             assign reg_file_defaults[i] = wo_defaults[C_S_AXI_DATA_WIDTH*(i+1)-1 : C_S_AXI_DATA_WIDTH*i];
	   end

	 // Unpacking Read Write registers
	 if (NUM_RW_REGS > 0)
	   for (i=0; i<NUM_RW_REGS; i=i+1) begin : RW
	     assign rw_regs[C_S_AXI_DATA_WIDTH*(i+1)-1 : C_S_AXI_DATA_WIDTH*i] = reg_file_wr_port[NUM_WO_REGS+i];
		 assign reg_file_rd_port[i] = reg_file_wr_port[NUM_WO_REGS+i];
             assign reg_file_defaults[NUM_WO_REGS+i] = rw_defaults[C_S_AXI_DATA_WIDTH*(i+1)-1 : C_S_AXI_DATA_WIDTH*i];
	   end

     // Unpacking Read Only registers
     if (NUM_RO_REGS > 0)
	   for (i=0; i<NUM_RO_REGS; i=i+1) begin : RO
	     assign reg_file_rd_port[NUM_RW_REGS+i] = ro_regs[C_S_AXI_DATA_WIDTH*(i+1)-1 : C_S_AXI_DATA_WIDTH*i];
           end
   endgenerate

   // -- Implementation

   assign ip2bus_error = 1'b0;

   // SW writes
   always @ (posedge bus2ip_clk) begin
     if (~bus2ip_resetn) begin
	   for (j=0; j<(NUM_WO_REGS+NUM_RW_REGS); j=j+1)
	     reg_file_wr_port[j] <= reg_file_defaults[j];

	   ip2bus_wrack <= 1'b0;
	 end
	 else begin
	   ip2bus_wrack <= 1'b0;

	   if (bus2ip_cs && !bus2ip_rnw && bus2ip_addr[addr_width_msb-1:addr_width_lsb] < (NUM_WO_REGS+NUM_RW_REGS)) begin
	     reg_file_wr_port[bus2ip_addr[addr_width_msb-1:addr_width_lsb]] <= bus2ip_data;
		 ip2bus_wrack <= 1'b1;
	   end
	 end
   end

   // SW reads
   always @ (posedge bus2ip_clk) begin
     if (~bus2ip_resetn) begin
	   ip2bus_data <= {C_S_AXI_DATA_WIDTH{1'b0}};
	   ip2bus_rdack <= 1'b0;
	 end
	 else begin
	   ip2bus_rdack <= 1'b0;

	   if (bus2ip_cs && bus2ip_rnw && bus2ip_addr[addr_width_msb-1:addr_width_lsb] >= (NUM_WO_REGS)) begin
	     ip2bus_data <= reg_file_rd_port[bus2ip_addr[addr_width_msb-1:addr_width_lsb]-NUM_WO_REGS];
		 ip2bus_rdack <= 1'b1;
	   end
	 end
   end

 endmodule
