/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        fifo_to_mem.v
 *
 *  Library:
 *        hw/osnt/pcores/nf10_pcap_replay_uengine_v1_00_a
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

// NOTE:
// (1) The burst of 4 is inherently covered with AXIS data wigth 256. The QID won't change
//		 until the burst is complete. 

module fifo_to_mem
#(
		parameter NUM_QUEUES       		 = 4,
		parameter NUM_QUEUES_BITS 		 = log2(NUM_QUEUES),
    parameter FIFO_DATA_WIDTH      = 144,
		parameter MEM_ADDR_WIDTH       = 19,
		parameter MEM_DATA_WIDTH       = 36,
		parameter MEM_BW_WIDTH         = 4,
		parameter MEM_BURST_LENGTH     = 4,
		parameter MEM_ADDR_LOW         = 0,
		parameter MEM_ADDR_HIGH        = MEM_ADDR_LOW+(2**MEM_ADDR_WIDTH)
)
(
    // Global Ports
    input                             clk,
		input															rst,
		
    // FIFO Ports
    output reg                        fifo_rd_en,
    input [FIFO_DATA_WIDTH-1:0]       fifo_data,
		input [NUM_QUEUES_BITS-1:0]				fifo_qid,
    input                             fifo_empty,
		
		// Memory Ports
    output reg                  			mem_ad_w_n,
		input															mem_wr_full,
    output reg [MEM_ADDR_WIDTH-1:0]  	mem_ad_wr,
		
    output reg 	                			mem_d_w_n,
    output [MEM_BW_WIDTH-1:0]    			mem_bwh_n,
    output [MEM_BW_WIDTH-1:0]    			mem_bwl_n,
    output reg [MEM_DATA_WIDTH-1:0]  	mem_dwl,
    output reg [MEM_DATA_WIDTH-1:0]  	mem_dwh,

    // Misc
		input [MEM_ADDR_WIDTH-1:0]  			q0_addr_low,
		input [MEM_ADDR_WIDTH-1:0]  			q0_addr_high,
		input [MEM_ADDR_WIDTH-1:0]  			q1_addr_low,
		input [MEM_ADDR_WIDTH-1:0]  			q1_addr_high,
		input [MEM_ADDR_WIDTH-1:0]  			q2_addr_low,
		input [MEM_ADDR_WIDTH-1:0]  			q2_addr_high,
		input [MEM_ADDR_WIDTH-1:0]  			q3_addr_low,
		input [MEM_ADDR_WIDTH-1:0]  			q3_addr_high,
		
		input															q0_enable,
		input															q1_enable,
		input															q2_enable,
		input															q3_enable,
		
    input                             sw_rst,
		input															cal_done
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
	
	reg													sw_rst_r;
	
	wire 												enable;
	
	reg [MEM_ADDR_WIDTH:0] 			mem_ad_wr_r0;
	reg 		  						 			mem_full_r0;
	reg [MEM_ADDR_WIDTH:0] 			mem_ad_wr_r1;
	reg 		  						 			mem_full_r1;
	reg [MEM_ADDR_WIDTH:0] 			mem_ad_wr_r2;
	reg 		  						 			mem_full_r2;
	reg [MEM_ADDR_WIDTH:0] 			mem_ad_wr_r3;
	reg 		  						 			mem_full_r3;
	
	reg   									 		mem_wr_n_r;
	reg 									 	 		mem_wr_n_c;
  reg [MEM_DATA_WIDTH-1:0] 		mem_dwl_c;
  reg [MEM_DATA_WIDTH-1:0] 		mem_dwh_c;
	
	// -- Assignments
	
	assign mem_bwh_n = {MEM_BW_WIDTH{1'b0}};
  assign mem_bwl_n = {MEM_BW_WIDTH{1'b0}};
	
	always @ (posedge clk) begin
		sw_rst_r <= sw_rst;
	end
	
	assign enable = |{q3_enable, q2_enable, q1_enable, q0_enable};
	
	// -- Modules and Logic
	
  always @ * begin
		fifo_rd_en = 0;
			
		mem_dwl_c  = fifo_data[FIFO_DATA_WIDTH/2-1:0];
		mem_dwh_c  = fifo_data[FIFO_DATA_WIDTH-1:FIFO_DATA_WIDTH/2];
		mem_wr_n_c = 1;
		
	  if (!fifo_empty && !mem_wr_full && cal_done) begin
			// Note: (1) We continue to drain the FIFO even if the respective queue is not enable or full
			//       (2) We are not checking the end-of-packet here. In case of FIFO full, partial packet can remain in the FIFO. Its the responsibility of the    
			//           Software to ensure that this doesn't happen.
			//       (3) Add counters for the number of packets written in the memory.
			fifo_rd_en = 1;
			
		  if (mem_wr_n_r) begin
				case (fifo_qid)
					'd0: if (!mem_full_r0 && q0_enable) mem_wr_n_c = 0;
					'd1: if (!mem_full_r1 && q1_enable) mem_wr_n_c = 0;
					'd2: if (!mem_full_r2 && q2_enable) mem_wr_n_c = 0;
					'd3: if (!mem_full_r3 && q3_enable) mem_wr_n_c = 0;
				endcase
			end
		end
	end
	
  always @ (posedge clk) begin
    if(rst || sw_rst_r) begin
			mem_wr_n_r 	 <= 1;
			mem_ad_w_n   <= 1;
			mem_d_w_n    <= 1;
			mem_dwl      <= {MEM_DATA_WIDTH{1'b0}};
			mem_dwh      <= {MEM_DATA_WIDTH{1'b0}};
			mem_ad_wr    <= MEM_ADDR_LOW;
			mem_full_r0  <= 0;
			mem_ad_wr_r0 <= {q0_addr_low, 1'b0};
			mem_full_r1  <= 0;
			mem_ad_wr_r1 <= {q1_addr_low, 1'b0};
			mem_full_r2  <= 0;
			mem_ad_wr_r2 <= {q2_addr_low, 1'b0};
			mem_full_r3  <= 0;
			mem_ad_wr_r3 <= {q3_addr_low, 1'b0};
    end
		else if (!enable) begin
			mem_wr_n_r 	 <= 1;
			mem_ad_w_n   <= 1;
			mem_d_w_n    <= 1;
			mem_dwl      <= {MEM_DATA_WIDTH{1'b0}};
			mem_dwh      <= {MEM_DATA_WIDTH{1'b0}};
			mem_ad_wr    <= MEM_ADDR_LOW;
			mem_full_r0  <= 0;
			mem_ad_wr_r0 <= {q0_addr_low, 1'b0};
			mem_full_r1  <= 0;
			mem_ad_wr_r1 <= {q1_addr_low, 1'b0};
			mem_full_r2  <= 0;
			mem_ad_wr_r2 <= {q2_addr_low, 1'b0};
			mem_full_r3  <= 0;
			mem_ad_wr_r3 <= {q3_addr_low, 1'b0};
    end
    else begin
			mem_wr_n_r <= mem_wr_n_c;
			mem_ad_w_n <= mem_wr_n_c;
			mem_d_w_n  <= mem_wr_n_c;
			mem_dwl  	 <= mem_dwl_c;
			mem_dwh 	 <= mem_dwh_c;
			
			if (!fifo_empty && !mem_wr_full && cal_done && (!mem_wr_n_c || !mem_wr_n_r)) begin
				case (fifo_qid)
					'd0: begin
						if (q0_enable) begin
							if (mem_ad_wr_r0 == ({q0_addr_high, 1'b0}-1)) 
								mem_full_r0 <= 1;
							else
								mem_ad_wr_r0 <= mem_ad_wr_r0+1;
						end
					end
					'd1: begin
						if (q1_enable) begin
							if (mem_ad_wr_r1 == ({q1_addr_high, 1'b0}-1)) 
								mem_full_r1 <= 1;
							else
								mem_ad_wr_r1 <= mem_ad_wr_r1+1;
						end
					end
					'd2: begin
						if (q2_enable) begin
							if (mem_ad_wr_r2 == ({q2_addr_high, 1'b0}-1)) 
								mem_full_r2 <= 1;
							else
								mem_ad_wr_r2 <= mem_ad_wr_r2+1;
						end
					end
					'd3: begin
						if (q3_enable) begin
							if (mem_ad_wr_r3 == ({q3_addr_high, 1'b0}-1)) 
								mem_full_r3 <= 1;
							else
								mem_ad_wr_r3 <= mem_ad_wr_r3+1;
						end
					end
				endcase
			end
			
			case (fifo_qid)
				'd0: mem_ad_wr <= mem_ad_wr_r0[MEM_ADDR_WIDTH:1];
				'd1: mem_ad_wr <= mem_ad_wr_r1[MEM_ADDR_WIDTH:1];
				'd2: mem_ad_wr <= mem_ad_wr_r2[MEM_ADDR_WIDTH:1];
				'd3: mem_ad_wr <= mem_ad_wr_r3[MEM_ADDR_WIDTH:1];
			endcase
		end
	end
	
endmodule

