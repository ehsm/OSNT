/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        mem_to_fifo.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_pcap_replay_uengine_v1_00_a
 *
 *  Module:
 *        mem_to_fifo
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

// TODO: 1) Add a packet size length check ...
//       2) Add number of interation check ...

module mem_to_fifo
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

		
		// Memory Ports
    output 		                   										mem_r_n,
		input																						mem_rd_full,
    output [MEM_ADDR_WIDTH-1:0]  										mem_ad_rd,
		input																						mem_qr_valid,
    input [MEM_DATA_WIDTH-1:0]  							  		mem_qrl,
    input [MEM_DATA_WIDTH-1:0]  										mem_qrh,

    // FIFO Ports
    output reg                                      fifo_wr_en,
    output reg [FIFO_DATA_WIDTH-1:0]                fifo_data,
    input                                           fifo_full,

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
	
	reg [MEM_ADDR_WIDTH:0] mem_ad_rd_c;
	reg 									 mem_r_n_c;

	// -- Assignments
	
	assign mem_r_n = mem_r_n_c;
	
	generate
		if (MEM_BURST_LENGTH==2)
 			assign mem_ad_rd = mem_ad_rd_c[MEM_ADDR_WIDTH-1:0];
		else if (MEM_BURST_LENGTH==4)
			assign mem_ad_rd = mem_ad_rd_c[MEM_ADDR_WIDTH:1];
	endgenerate
	
  // -- Modules and Logic
	
  always @ (posedge clk) begin
    if(rst || sw_rst) begin
      mem_ad_rd_c  <= MEM_ADDR_LOW;
    end
    else begin
		  if (!mem_rd_full && cal_done) begin
				if (mem_ad_rd_c == MEM_ADDR_HIGH) 
					mem_ad_rd_c <= MEM_ADDR_LOW;
				else
					mem_ad_rd_c <= mem_ad_rd_c + 1;	 
			end
    end
  end
	
  always @ (posedge clk) begin
    if(rst || sw_rst) begin
			mem_r_n_c <= 1;
    end
    else begin
			mem_r_n_c <= 1;
		
		  if (!mem_rd_full && cal_done) begin
				if (MEM_BURST_LENGTH==2 || (MEM_BURST_LENGTH==4 && mem_r_n_c))
					mem_r_n_c <= 0;
    	end
		end
  end
	
  always @ (posedge clk) begin
    if(rst || sw_rst) begin
			fifo_wr_en <= 0;
      fifo_data  <= {FIFO_DATA_WIDTH{1'b0}};
    end
    else begin
			fifo_wr_en <= 0;
		
		  if (mem_qr_valid && !fifo_full) begin
				fifo_wr_en <= 1;
				fifo_data  <= {mem_qrh, mem_qrl};
			end
    end
  end
	
endmodule

