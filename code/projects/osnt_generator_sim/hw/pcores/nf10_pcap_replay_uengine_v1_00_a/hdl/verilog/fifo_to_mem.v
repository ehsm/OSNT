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
		parameter FIFO_NUM_QUEUES      = 4,
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
    input [log2(FIFO_NUM_QUEUES)-1:0]               fifo_qid,
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
		input [MEM_ADDR_WIDTH-1:0]  									  mem_addr_low_q0,
		input [MEM_ADDR_WIDTH-1:0]  										mem_addr_high_q0,
		input [MEM_ADDR_WIDTH-1:0]  									  mem_addr_low_q1,
		input [MEM_ADDR_WIDTH-1:0]  										mem_addr_high_q1,
		input [MEM_ADDR_WIDTH-1:0]  									  mem_addr_low_q2,
		input [MEM_ADDR_WIDTH-1:0]  										mem_addr_high_q2,
		input [MEM_ADDR_WIDTH-1:0]  									  mem_addr_low_q3,
		input [MEM_ADDR_WIDTH-1:0]  										mem_addr_high_q3,
		
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
	
	localparam DATA_STAGE_0 = 0;
	localparam DATA_STAGE_1 = 1;
		
	// -- Signals
	
	integer                         i, j;
	
  reg                       			state;
  reg                       			next_state;
	
	reg [log2(FIFO_NUM_QUEUES)-1:0] fifo_qid_r;

	reg 									 					mem_wr_n_c;
  reg [MEM_DATA_WIDTH-1:0]  			mem_dwl_c;
  reg [MEM_DATA_WIDTH-1:0]  			mem_dwh_c;
	reg [MEM_ADDR_WIDTH:0] 					mem_ad_wr_r[0:FIFO_NUM_QUEUES-1];	
	reg [MEM_ADDR_WIDTH:0] 					mem_ad_wr_c[0:FIFO_NUM_QUEUES-1];
	reg [MEM_ADDR_WIDTH-1:0] 				mem_ad_low[0:FIFO_NUM_QUEUES-1];
	reg [MEM_ADDR_WIDTH-1:0] 				mem_ad_high[0:FIFO_NUM_QUEUES-1];
	reg 														mem_full_r[0:FIFO_NUM_QUEUES-1];
	reg 														mem_full_c[0:FIFO_NUM_QUEUES-1];
	

	// -- Assignments
	
	assign mem_bwh_n = {MEM_BW_WIDTH{1'b0}};
  assign mem_bwl_n = {MEM_BW_WIDTH{1'b0}};
  
	// -- Modules and Logic
	
	always @ * begin
		for (i=0; i<FIFO_NUM_QUEUES; i=i+1) begin
			if (i==0) begin
				mem_ad_low[i]  = mem_addr_low_q0;
				mem_ad_high[i] = mem_addr_high_q0;
			end
			else if (i==1) begin
				mem_ad_low[i]  = mem_addr_low_q1;
				mem_ad_high[i] = mem_addr_high_q1;
			end
			else if (i==2) begin
				mem_ad_low[i]  = mem_addr_low_q2;
				mem_ad_high[i] = mem_addr_high_q2;
			end
			else if (i==3) begin
				mem_ad_low[i]  = mem_addr_low_q3;
				mem_ad_high[i] = mem_addr_high_q3;
			end
		end
	end
	
	// ---- State Machine [Combinational]
	always @ * begin
		next_state = state;
		
		fifo_rd_en = 0;
		
		for (j=0; j<FIFO_NUM_QUEUES; j=j+1) begin
			mem_ad_wr_c[j] = mem_ad_wr_r[j];
			mem_full_c[j]  = mem_full_r[j];
		end
		
		mem_dwl_c  = mem_dwl;
		mem_dwh_c  = mem_dwh;
		mem_wr_n_c = 1;
		
		case (state)
			DATA_STAGE_0: begin
		  	if (!fifo_empty && !mem_wr_full && cal_done) begin
					if (mem_full_r[fifo_qid]) begin
						fifo_rd_en = 1;
					end
					else begin
						if (MEM_BURST_LENGTH==2 || MEM_BURST_LENGTH==4)
							mem_wr_n_c = 0;
						
						if (mem_ad_wr_r[fifo_qid] == (mem_ad_high[fifo_qid]-2)) 
							mem_full_c[fifo_qid] = 1;
						else
							mem_ad_wr_c[fifo_qid] = mem_ad_wr_r[fifo_qid] + 1;
						
						mem_dwl_c = fifo_data[1*FIFO_DATA_WIDTH/4-1:0*FIFO_DATA_WIDTH/4];
						mem_dwh_c = fifo_data[2*FIFO_DATA_WIDTH/4-1:1*FIFO_DATA_WIDTH/4];
						
						next_state = DATA_STAGE_1;
					end
				end
			end
			DATA_STAGE_1: begin
				if (!mem_wr_full  && cal_done) begin
					fifo_rd_en = 1;
					
					if (MEM_BURST_LENGTH == 2)
						mem_wr_n_c = 0;
				
					mem_ad_wr_c[fifo_qid] = mem_ad_wr_r[fifo_qid] + 1;
					
					mem_dwl_c  = fifo_data[3*FIFO_DATA_WIDTH/4-1:2*FIFO_DATA_WIDTH/4];
					mem_dwh_c  = fifo_data[4*FIFO_DATA_WIDTH/4-1:3*FIFO_DATA_WIDTH/4];
					
					next_state = DATA_STAGE_0;
				end
			end
		endcase
	end
	
	// ---- State Machine [Sequential]
  always @ (posedge clk) begin
    if (rst) begin
			state 			 <= DATA_STAGE_0;
		
			fifo_qid_r 	 <= {log2(FIFO_NUM_QUEUES){1'b0}};
		
			mem_ad_w_n   <= 1;
			mem_d_w_n    <= 1;
			mem_dwl      <= {MEM_DATA_WIDTH{1'b0}};
			mem_dwh      <= {MEM_DATA_WIDTH{1'b0}};
			mem_ad_wr    <= MEM_ADDR_LOW;
      
			for (j=0; j<FIFO_NUM_QUEUES; j=j+1) begin
				mem_ad_wr_r[j] <= MEM_ADDR_LOW;
				mem_full_r[j]  <= 0;
			end
    end
		else if (sw_rst) begin
			state <= DATA_STAGE_0;
			
			fifo_qid_r 	 <= {log2(FIFO_NUM_QUEUES){1'b0}};
		
			mem_ad_w_n   <= 1;
			mem_d_w_n    <= 1;
			mem_dwl      <= {MEM_DATA_WIDTH{1'b0}};
			mem_dwh      <= {MEM_DATA_WIDTH{1'b0}};
			mem_ad_wr    <= MEM_ADDR_LOW;
      
			for (j=0; j<FIFO_NUM_QUEUES; j=j+1) begin
				mem_ad_wr_r[j] <= mem_ad_low[j];
				mem_full_r[j]  <= 0;
			end
    end
    else begin
			state <= next_state;
			
			fifo_qid_r <= fifo_qid;
		
			mem_ad_w_n  <= mem_wr_n_c;
			mem_d_w_n   <= mem_wr_n_c;
			mem_dwl  	  <= mem_dwl_c;
			mem_dwh 	  <= mem_dwh_c;
			
			for (j=0; j<FIFO_NUM_QUEUES; j=j+1) begin
				mem_ad_wr_r[j] <= mem_ad_wr_c[j];
				mem_full_r[j]  <= mem_full_c[j];
			end
			
			if (MEM_BURST_LENGTH==2)
				mem_ad_wr <= mem_ad_wr_r[fifo_qid_r][MEM_ADDR_WIDTH-1:0];
			else if (MEM_BURST_LENGTH==4)
				mem_ad_wr <= mem_ad_wr_r[fifo_qid_r][MEM_ADDR_WIDTH:1]; 
    end
	end
	
endmodule

