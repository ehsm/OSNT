/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        xil_async_fifo.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_pcap_replay_uengine_v1_00_a
 *
 *  Module:
 *        xil_async_fifo
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

module xil_async_fifo
#(
    parameter DIN_WIDTH  = 256,
    parameter DEPTH   = 16,
    parameter DOUT_WIDTH = 64
)
(
    input                      rst,
    input                      wr_clk,
    input                      wr_en,
    input [DIN_WIDTH-1:0]  		 din,
    input                      rd_clk,
    input                      rd_en,
    output [DOUT_WIDTH-1:0] 	 dout,
    output                     full,
    output                     empty
);

  // -- Local Params
  //localparam WR_DEPTH = (WR_DATA_WIDTH >= RD_DATA_WIDTH) ? DEPTH : (RD_DATA_WIDTH/WR_DATA_WIDTH)*DEPTH;
  //localparam RD_DEPTH = (WR_DATA_WIDTH >= RD_DATA_WIDTH) ? (WR_DATA_WIDTH/RD_DATA_WIDTH)*DEPTH : DEPTH;

  // -- Modules and Logic
	
  generate 
	  if (DIN_WIDTH==DOUT_WIDTH) begin: _fifo_292_to_292
		  fifo_generator_v8_4_292_to_292 _inst (
		    .rst(rst), // input rst
		    .wr_clk(wr_clk), // input wr_clk
		    .rd_clk(rd_clk), // input rd_clk
		    .din(din), // input [291 : 0] din
		    .wr_en(wr_en), // input wr_en
		    .rd_en(rd_en), // input rd_en
		    .dout(dout), // output [291 : 0] dout
		    .full(full), // output full
		    .empty(empty) // output empty
		  );
		end
	endgenerate
	
endmodule