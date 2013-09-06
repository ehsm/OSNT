/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        fifo_to_mem.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_pcap_replay_uengine_v1_00_a
 *
 *  Module:
 *        fifo_to_mem
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

// TODO: Add a packet size length check ...

module fifo_to_mem
#(
    parameter FIFO_DATA_WIDTH      = 72,
		parameter MEM_ADDR_WIDTH       = 19,
		parameter MEM_DATA_WIDTH       = 36,
		parameter MEM_BW_WIDTH         = 4,
		parameter MEM_BURST_LENGTH     = 2,
		parameter MEM_ADDR_LOW         = 0,
		parameter MEM_ADDR_HIGH        = MEM_ADDR_LOW+(2**MEM_ADDR_WIDTH/MEM_BURST_LENGTH)
)
(
    // Global Ports
    input                                           clk,
		input																						rst,
		
    // FIFO Ports
    output reg                                      fifo_rd_en,
    input [FIFO_DATA_WIDTH-1:0]                     fifo_data,
    input                                           fifo_empty,
		
		// Memory Ports
    output reg                  										mem_ad_w_n,
    output reg 	                										mem_d_w_n,
		input																						mem_wr_full,
    output reg [MEM_ADDR_WIDTH-1:0]  								mem_ad_wr,
    output [MEM_BW_WIDTH-1:0]    										mem_bwh_n,
    output [MEM_BW_WIDTH-1:0]    										mem_bwl_n,
    output reg [MEM_DATA_WIDTH-1:0]  							  mem_dwl,
    output reg [MEM_DATA_WIDTH-1:0]  								mem_dwh,

    // Misc
    input                                           sw_rst,
		input																						cal_done
);

  // -- Local Functions
  function integer log2;
    input integer number;
    begin
       log2=0;
       while(2**log2<number) begin
          log2=log2+1;
       end
    end
  endfunction

  // -- Internal Parameters
	
	// -- Signals
	
	reg [MEM_ADDR_WIDTH:0] 		mem_ad_wr_c;
	reg   									  mem_wr_n;
	reg 									 		mem_wr_n_c;
  reg [MEM_DATA_WIDTH-1:0]  mem_dwl_c;
  reg [MEM_DATA_WIDTH-1:0]  mem_dwh_c;
	

	// -- Assignments
	
	assign mem_bwh_n = {MEM_BW_WIDTH{1'b0}};
  assign mem_bwl_n = {MEM_BW_WIDTH{1'b0}};
  
	// -- Modules and Logic
	
  always @ * begin
		fifo_rd_en = 0;
			
		mem_dwl_c  = fifo_data[FIFO_DATA_WIDTH/2-1:0];
		mem_dwh_c  = fifo_data[FIFO_DATA_WIDTH-1:FIFO_DATA_WIDTH/2];
		mem_wr_n_c = 1;
		
	  if (!fifo_empty && !mem_wr_full && cal_done) begin
			fifo_rd_en = 1;
	
			if (MEM_BURST_LENGTH==2 || (MEM_BURST_LENGTH==4 && mem_wr_n))
				mem_wr_n_c = 0;
		end
	end
	
  always @ (posedge clk) begin
    if(rst || sw_rst) begin
			mem_wr_n 	   <= 1;
			mem_ad_w_n   <= 1;
			mem_d_w_n    <= 1;
			mem_dwl      <= {MEM_DATA_WIDTH{1'b0}};
			mem_dwh      <= {MEM_DATA_WIDTH{1'b0}};
			mem_ad_wr    <= MEM_ADDR_LOW;
      mem_ad_wr_c  <= MEM_ADDR_LOW;
    end
    else begin
			mem_wr_n 	 <= mem_wr_n_c;
			mem_ad_w_n <= mem_wr_n_c;
			mem_d_w_n  <= mem_wr_n_c;
			mem_dwl  	 <= mem_dwl_c;
			mem_dwh 	 <= mem_dwh_c;
			
			if (MEM_BURST_LENGTH==2)
				mem_ad_wr <= mem_ad_wr_c[MEM_ADDR_WIDTH-1:0];
			else if (MEM_BURST_LENGTH==4)
				mem_ad_wr <= mem_ad_wr_c[MEM_ADDR_WIDTH:1];
			
			if (!fifo_empty && !mem_wr_full && cal_done && (!mem_wr_n_c || !mem_wr_n)) begin
				if (mem_ad_wr_c == MEM_ADDR_HIGH) 
					mem_ad_wr_c <= MEM_ADDR_LOW;
				else
					mem_ad_wr_c <= mem_ad_wr_c + 1;
			end	 
    end
	end
	
endmodule

