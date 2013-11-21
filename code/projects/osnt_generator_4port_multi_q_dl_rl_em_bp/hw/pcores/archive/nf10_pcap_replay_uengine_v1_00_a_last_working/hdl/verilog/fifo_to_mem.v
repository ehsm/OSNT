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
    output 		                                      fifo_rd_en,
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
		input [MEM_ADDR_WIDTH-1:0]  										mem_addr_high,
		
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
	
	reg [MEM_ADDR_WIDTH:0] 						 mem_ad_wr_r;
	reg 															 mem_full_r;
	reg   									  				 mem_wr_n_r;
	reg 									 						 mem_wr_n_c;
  reg [MEM_DATA_WIDTH-1:0]  				 mem_dwl_c;
  reg [MEM_DATA_WIDTH-1:0]  				 mem_dwh_c;
	reg                       				 cal_done_r;
	
  reg                                ififo_rd_en;
  wire                               ififo_wr_en;
  wire                               ififo_nearly_full;
  wire                               ififo_empty;
  wire  [FIFO_DATA_WIDTH-1:0]    		 ififo_data;

	// -- Assignments
	
	assign mem_bwh_n = {MEM_BW_WIDTH{1'b0}};
  assign mem_bwl_n = {MEM_BW_WIDTH{1'b0}};
  
	// -- Modules and Logic
  fallthrough_small_fifo #(.WIDTH(FIFO_DATA_WIDTH), .MAX_DEPTH_BITS(2))
    input_fifo_inst
      ( .din         (fifo_data),
        .wr_en       (ififo_wr_en),
        .rd_en       (ififo_rd_en),
        .dout        (ififo_data),
        .full        (),
        .prog_full   (),
        .nearly_full (ififo_nearly_full),
        .empty       (ififo_empty),
        .reset       (rst || sw_rst),
        .clk         (clk)
      );
	
	assign fifo_rd_en = !ififo_nearly_full && !fifo_empty;
	assign ififo_wr_en = fifo_rd_en;
	
	
	always @ (posedge clk) 
		cal_done_r <= cal_done;
	
  always @ * begin
		ififo_rd_en = 0;
			
		mem_dwl_c  = ififo_data[FIFO_DATA_WIDTH/2-1:0];
		mem_dwh_c  = ififo_data[FIFO_DATA_WIDTH-1:FIFO_DATA_WIDTH/2];
		mem_wr_n_c = 1;
		
	  if (!ififo_empty && !mem_wr_full && cal_done_r) begin
			ififo_rd_en = 1;
			//Note: we are draining the input FIFO even if the QDR memory is full ... (this should be properly handled by the software)
			
			if (!mem_full_r && (MEM_BURST_LENGTH==2 || (MEM_BURST_LENGTH==4 && mem_wr_n_r)))
				mem_wr_n_c = 0;
		end
	end
	
  always @ (posedge clk) begin
    if(rst || sw_rst) begin
			mem_wr_n_r 	 <= 1;
			mem_ad_w_n   <= 1;
			mem_d_w_n    <= 1;
			mem_dwl      <= {MEM_DATA_WIDTH{1'b0}};
			mem_dwh      <= {MEM_DATA_WIDTH{1'b0}};
			mem_ad_wr    <= MEM_ADDR_LOW;
      mem_ad_wr_r  <= MEM_ADDR_LOW;
			mem_full_r   <= 0;
    end
    else begin
			mem_wr_n_r <= mem_wr_n_c;
			mem_ad_w_n <= mem_wr_n_c;
			mem_d_w_n  <= mem_wr_n_c;
			mem_dwl  	 <= mem_dwl_c;
			mem_dwh 	 <= mem_dwh_c;
			
			if (!ififo_empty && !mem_wr_full && cal_done_r && (!mem_wr_n_c || !mem_wr_n_r)) begin
				if (mem_ad_wr_r == mem_addr_high-1) 
					mem_full_r  <= 1;
				else
					mem_ad_wr_r <= mem_ad_wr_r + 1;
			end
			
			if (MEM_BURST_LENGTH == 2)
				mem_ad_wr <= mem_ad_wr_r[MEM_ADDR_WIDTH-1:0];
			else if (MEM_BURST_LENGTH == 4)
				mem_ad_wr <= mem_ad_wr_r[MEM_ADDR_WIDTH:1];	 
    end
	end
	
endmodule

