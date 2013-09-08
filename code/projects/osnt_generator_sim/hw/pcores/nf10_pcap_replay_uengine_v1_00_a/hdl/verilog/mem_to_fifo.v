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
		parameter FIFO_NUM_QUEUES      = 4,
		parameter MEM_ADDR_WIDTH       = 19,
		parameter MEM_DATA_WIDTH       = 36,
		parameter MEM_BW_WIDTH         = 4,
		parameter MEM_BURST_LENGTH     = 2,
		parameter MEM_ADDR_LOW         = 0,
		parameter MEM_ADDR_HIGH        = MEM_ADDR_LOW+(2**MEM_ADDR_WIDTH/MEM_BURST_LENGTH),
		parameter REPLAY_COUNT_WIDTH   = 32
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
    output reg  																		fifo_wr_en,
    output reg [FIFO_DATA_WIDTH-1:0]                fifo_data,
    input  											                    fifo_full,

    // Misc
		input																						enable_q0,
		input [MEM_ADDR_WIDTH-1:0]  									  mem_ad_low_q0,
		input [MEM_ADDR_WIDTH-1:0]  										mem_ad_high_q0,
		input	[REPLAY_COUNT_WIDTH-1:0]		  						replay_count_q0,
		input																						enable_q1,
		input [MEM_ADDR_WIDTH-1:0]  									  mem_ad_low_q1,
		input [MEM_ADDR_WIDTH-1:0]  										mem_ad_high_q1,
		input	[REPLAY_COUNT_WIDTH-1:0]		  						replay_count_q1,
		input																						enable_q2,
		input [MEM_ADDR_WIDTH-1:0]  									  mem_ad_low_q2,
		input [MEM_ADDR_WIDTH-1:0]  										mem_ad_high_q2,
		input	[REPLAY_COUNT_WIDTH-1:0]		  						replay_count_q2,
		input																						enable_q3,
		input [MEM_ADDR_WIDTH-1:0]  									  mem_ad_low_q3,
		input [MEM_ADDR_WIDTH-1:0]  										mem_ad_high_q3,
		input	[REPLAY_COUNT_WIDTH-1:0]		  						replay_count_q3,
		
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
	
	integer                         	i, j;
	
  reg                       				state;
	
	reg [log2(FIFO_NUM_QUEUES)-1:0] 	cur_qid;
	reg [log2(FIFO_NUM_QUEUES)-1:0] 	cur_qid_r;
	
	reg	[FIFO_NUM_QUEUES-1:0]	  			enable;
	reg 									 						mem_r_n_c;
	reg [MEM_ADDR_WIDTH:0] 						mem_ad_rd_r[0:FIFO_NUM_QUEUES-1];	
	reg [MEM_ADDR_WIDTH-1:0] 					mem_ad_low[0:FIFO_NUM_QUEUES-1];
	reg [MEM_ADDR_WIDTH-1:0] 					mem_ad_high[0:FIFO_NUM_QUEUES-1];
	reg	[REPLAY_COUNT_WIDTH-1:0]			replay_count[0:FIFO_NUM_QUEUES-1];
	reg	[REPLAY_COUNT_WIDTH-1:0]			replay_count_r[0:FIFO_NUM_QUEUES-1];

	// -- Assignments
	
	assign mem_r_n = mem_r_n_c;
	
	generate
		if (MEM_BURST_LENGTH==2)
 			assign mem_ad_rd = mem_ad_rd_r[cur_qid_r][MEM_ADDR_WIDTH-1:0];
		else if (MEM_BURST_LENGTH==4)
			assign mem_ad_rd = mem_ad_rd_r[cur_qid_r][MEM_ADDR_WIDTH:1];
	endgenerate
	
  // -- Modules and Logic
	
	always @ * begin
		for (i=0; i<FIFO_NUM_QUEUES; i=i+1) begin
			if (i==0) begin
				enable[i]       = enable_q0;
				mem_ad_low[i]   = mem_ad_low_q0;
				mem_ad_high[i]  = mem_ad_high_q0;
				replay_count[i] = replay_count_q0;
			end
			else if (i==1) begin
				enable[i]       = enable_q1;
				mem_ad_low[i]   = mem_ad_low_q1;
				mem_ad_high[i]  = mem_ad_high_q1;
				replay_count[i] = replay_count_q1;
			end
			else if (i==2) begin
				enable[i]       = enable_q2;
				mem_ad_low[i]   = mem_ad_low_q2;
				mem_ad_high[i]  = mem_ad_high_q2;
				replay_count[i] = replay_count_q2;
			end
			else if (i==3) begin
				enable[i]       = enable_q3;
				mem_ad_low[i]   = mem_ad_low_q3;
				mem_ad_high[i]  = mem_ad_high_q3;
				replay_count[i] = replay_count_q3;
			end
		end
	end
	
  always @ (posedge clk) begin
    if (rst || sw_rst) begin
			mem_r_n_c <= 1;
			
			for (j=0; j<FIFO_NUM_QUEUES; j=j+1) begin
				mem_ad_rd_r[j] 		<= mem_ad_low[j];
				replay_count_r[j] <= replay_count[j];
			end
			
			cur_qid   <= {log2(FIFO_NUM_QUEUES){1'b0}};
			cur_qid_r <= {log2(FIFO_NUM_QUEUES){1'b0}};
    end
    else begin
			mem_r_n_c <= 1;
			cur_qid_r <= cur_qid;
		
			if (!mem_rd_full && cal_done) begin
		  	if (enable[cur_qid] && replay_count_r[cur_qid]!=0) begin
					if (MEM_BURST_LENGTH==2 || (MEM_BURST_LENGTH==4 && mem_r_n_c)) begin
						mem_r_n_c <= 0;
						cur_qid <= cur_qid + 1;
					end
				
					if (mem_ad_rd_r[cur_qid] == mem_ad_high[cur_qid]-1) begin // Note: mem_ad_high should be equal to the sum of the size
						mem_ad_rd_r[cur_qid] 	  <= mem_ad_low[cur_qid];         // of all packets in the respective memory queue
						replay_count_r[cur_qid] <= replay_count_r[cur_qid] - 1;
					end
					else
						mem_ad_rd_r[cur_qid] <= mem_ad_rd_r[cur_qid] + 1;	 
				end
				else // cycle between queues until you get the one which is enabled
					cur_qid <= cur_qid + 1;
			end
    end
  end
	
	generate
		if (MEM_DATA_WIDTH == 72) begin: _mem_width_72
  		always @ (posedge clk) begin
  		  if (rst || sw_rst) begin
					state <= DATA_STAGE_0;
				
					fifo_wr_en <= 0;
  		    fifo_data  <= {FIFO_DATA_WIDTH{1'b0}};
  		  end
  		  else begin
					fifo_wr_en <= 0;
					
					case (state)
						DATA_STAGE_0: begin
							if (mem_qr_valid && !fifo_full) begin
								fifo_data[FIFO_DATA_WIDTH/2-1:0] <= {mem_qrh, mem_qrl};
								state <= DATA_STAGE_1;
							end
						end
						DATA_STAGE_1: begin
							if (mem_qr_valid && !fifo_full) begin
								fifo_data[FIFO_DATA_WIDTH-1:FIFO_DATA_WIDTH/2] <= {mem_qrh, mem_qrl};
								fifo_wr_en <= 1;
								state <= DATA_STAGE_0;
							end
						end
					endcase
  		  end
  		end
		end
	endgenerate
	
endmodule

