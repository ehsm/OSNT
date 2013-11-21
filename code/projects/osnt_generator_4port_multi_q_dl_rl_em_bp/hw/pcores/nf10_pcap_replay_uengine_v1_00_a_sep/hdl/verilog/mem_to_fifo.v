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

module mem_to_fifo
#(
		parameter NUM_QUEUES           = 4,
		parameter NUM_QUEUES_BITS 		 = log2(NUM_QUEUES),
    parameter FIFO_DATA_WIDTH      = 144,
		parameter MEM_ADDR_WIDTH       = 19,
		parameter MEM_DATA_WIDTH       = 36,
		parameter MEM_BW_WIDTH         = 4,
		parameter MEM_BURST_LENGTH     = 2,
		parameter MEM_ADDR_LOW         = 0,
		parameter MEM_ADDR_HIGH        = MEM_ADDR_LOW+(2**MEM_ADDR_WIDTH),
		parameter REPLAY_COUNT_WIDTH   = 32,
		parameter SIM_ONLY	           = 0			
)
(
    // Global Ports
    input                             clk,
		input															rst,

		
		// Memory Ports
    output reg                   		  mem_r_n,
		input														  mem_rd_full,
    output reg [MEM_ADDR_WIDTH-1:0]   mem_ad_rd,
		
		input														  mem_qr_valid,
    input [MEM_DATA_WIDTH-1:0]  		  mem_qrl,
    input [MEM_DATA_WIDTH-1:0]  		  mem_qrh,

    // FIFO Ports
    output reg                        q0_fifo_wr_en,
    output reg [FIFO_DATA_WIDTH-1:0]  q0_fifo_data,
    input                           	q0_fifo_full,
		input                           	q0_fifo_prog_full,
		
    output reg                        q1_fifo_wr_en,
    output reg [FIFO_DATA_WIDTH-1:0]  q1_fifo_data,
    input                           	q1_fifo_full,
		input                           	q1_fifo_prog_full,
		
    output reg                        q2_fifo_wr_en,
    output reg [FIFO_DATA_WIDTH-1:0]  q2_fifo_data,
    input                           	q2_fifo_full,
		input                           	q2_fifo_prog_full,
		
    output reg                        q3_fifo_wr_en,
    output reg [FIFO_DATA_WIDTH-1:0]  q3_fifo_data,
    input                           	q3_fifo_full,
		input                           	q3_fifo_prog_full,

    // Misc
		input [MEM_ADDR_WIDTH-1:0]  			q0_addr_low,
		input [MEM_ADDR_WIDTH-1:0]  			q0_addr_high,
		input [MEM_ADDR_WIDTH-1:0]  			q1_addr_low,
		input [MEM_ADDR_WIDTH-1:0]  			q1_addr_high,
		input [MEM_ADDR_WIDTH-1:0]  			q2_addr_low,
		input [MEM_ADDR_WIDTH-1:0]  			q2_addr_high,
		input [MEM_ADDR_WIDTH-1:0]  			q3_addr_low,
		input [MEM_ADDR_WIDTH-1:0]  			q3_addr_high,
		
		input	[REPLAY_COUNT_WIDTH-1:0]		q0_replay_count,
		input	[REPLAY_COUNT_WIDTH-1:0]		q1_replay_count,
		input	[REPLAY_COUNT_WIDTH-1:0]		q2_replay_count,
		input	[REPLAY_COUNT_WIDTH-1:0]		q3_replay_count,

		input	 														q0_start_replay,
		input	 														q1_start_replay,
		input	 														q2_start_replay,
		input	 														q3_start_replay,
		
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
	
	wire													enable;
	
	wire													oq0_enable;
	wire													oq1_enable;
	wire													oq2_enable;
	wire													oq3_enable;
	
  reg                        		q0_fifo_wr_en_r0;
  reg [FIFO_DATA_WIDTH-1:0]  		q0_fifo_data_r0;
  reg                        		q0_fifo_wr_en_r1;
  reg [FIFO_DATA_WIDTH-1:0]  		q0_fifo_data_r1;	
  reg                        		q1_fifo_wr_en_r0;
  reg [FIFO_DATA_WIDTH-1:0]  		q1_fifo_data_r0;
  reg                        		q1_fifo_wr_en_r1;
  reg [FIFO_DATA_WIDTH-1:0]  		q1_fifo_data_r1;	
  reg                        		q2_fifo_wr_en_r0;
  reg [FIFO_DATA_WIDTH-1:0]  		q2_fifo_data_r0;
  reg                        		q2_fifo_wr_en_r1;
  reg [FIFO_DATA_WIDTH-1:0]  		q2_fifo_data_r1;	
  reg                        		q3_fifo_wr_en_r0;
  reg [FIFO_DATA_WIDTH-1:0]  		q3_fifo_data_r0;
  reg                        		q3_fifo_wr_en_r1;
  reg [FIFO_DATA_WIDTH-1:0]  		q3_fifo_data_r1;
	
	reg 													trigger;
	reg [NUM_QUEUES_BITS:0]				cur_qid;
	                             							
	reg 							 						mem_r_n_r0;
	reg [MEM_ADDR_WIDTH:0]  			mem_ad_rd_r0;
	reg [REPLAY_COUNT_WIDTH-1:0] 	replay_count_r0;
	reg 							 						mem_r_n_r1;
	reg [MEM_ADDR_WIDTH:0]  			mem_ad_rd_r1;
	reg [REPLAY_COUNT_WIDTH-1:0] 	replay_count_r1;
	reg 							 						mem_r_n_r2;
	reg [MEM_ADDR_WIDTH:0]  			mem_ad_rd_r2;
	reg [REPLAY_COUNT_WIDTH-1:0] 	replay_count_r2;
	reg 							 						mem_r_n_r3;
	reg [MEM_ADDR_WIDTH:0]  			mem_ad_rd_r3;
	reg [REPLAY_COUNT_WIDTH-1:0] 	replay_count_r3;
	
  reg                           fifo_wr_en;
  reg                           fifo_rd_en;
  reg  [NUM_QUEUES_BITS-1:0]   	fifo_din_qid;
	wire [NUM_QUEUES_BITS-1:0]   	fifo_dout_qid;
	wire													fifo_empty;
  wire                          fifo_full;

	// -- Assignments
	
  // -- Modules and Logic
	
	// --- Arbitration logic
	
	// Note: the prog_full signal is asserted when there are ~16 locations left in the FIFO. This is based on the assumption that after seeing the prog_full the max number of read requests in flight would be no more than 14.
	
	assign enable = (cal_done && !fifo_full && !mem_rd_full && 
									|{q3_start_replay, q2_start_replay, q1_start_replay, q0_start_replay}) ? 1 : trigger;
									
	assign oq0_enable = !q0_fifo_prog_full && q0_start_replay && q0_enable;
	assign oq1_enable = !q1_fifo_prog_full && q1_start_replay && q1_enable;
	assign oq2_enable = !q2_fifo_prog_full && q2_start_replay && q2_enable;
	assign oq3_enable = !q3_fifo_prog_full && q3_start_replay && q3_enable;
	
	always @ (posedge clk) begin
		if(rst || sw_rst) begin
			trigger <= 0;
			cur_qid <= -1;
		end
		else if (enable) begin
			trigger <= trigger + 1;
			
			if (trigger) begin
				case (cur_qid)
					'd0: begin
						 			if (oq1_enable) cur_qid <= 1; 
						 else if (oq2_enable) cur_qid <= 2; 
						 else if (oq3_enable) cur_qid <= 3; 
						 else if (oq0_enable) cur_qid <= 0;
						 else 								cur_qid <= -1;
					end                               
					'd1: begin                        
						      if (oq2_enable) cur_qid <= 2; 
						 else if (oq3_enable) cur_qid <= 3; 
						 else if (oq0_enable) cur_qid <= 0;
						 else if (oq1_enable) cur_qid <= 1;
						 else 								cur_qid <= -1;
					end                               
					'd2: begin                        
						 			if (oq3_enable) cur_qid <= 3; 
						 else if (oq0_enable) cur_qid <= 0;
						 else if (oq1_enable) cur_qid <= 1; 
						 else if (oq2_enable) cur_qid <= 2;
						 else 								cur_qid <= -1;
					end                               
					'd3: begin                        
						      if (oq0_enable) cur_qid <= 0;
						 else if (oq1_enable) cur_qid <= 1; 
						 else if (oq2_enable) cur_qid <= 2; 
						 else if (oq3_enable) cur_qid <= 3; 
						 else 								cur_qid <= -1;
					end
					default: begin                        
						      if (oq0_enable) cur_qid <= 0;
						 else if (oq1_enable) cur_qid <= 1; 
						 else if (oq2_enable) cur_qid <= 2; 
						 else if (oq3_enable) cur_qid <= 3; 
						 else 								cur_qid <= -1;
					end
				endcase
			end
		end
	end
	
	// Address generation logic
	
  always @ (posedge clk) begin
    if(rst || sw_rst) begin
			mem_r_n_r0 		 	<= 1;
			mem_ad_rd_r0   	<= {q0_addr_low, 1'b0};
			replay_count_r0 <= q0_replay_count;
    end
    else if(!q0_enable) begin
			mem_r_n_r0 		 	<= 1;
			mem_ad_rd_r0   	<= {q0_addr_low, 1'b0};
			replay_count_r0 <= q0_replay_count;
    end
    else begin
			mem_r_n_r0 			<= 1;
			
			if (enable) begin
				if (cur_qid=='d0) begin
					if (replay_count_r0>0) begin
						if (mem_r_n_r0)
							mem_r_n_r0 <= 0;
				  
						if (mem_ad_rd_r0 >= ({q0_addr_high, 1'b0}-1)) begin
							mem_ad_rd_r0 <= {q0_addr_low, 1'b0};
							replay_count_r0 <= replay_count_r0-1;
						end
						else
							mem_ad_rd_r0 <= mem_ad_rd_r0+1;
					end
				end
			end
    end
  end
	
  always @ (posedge clk) begin
    if(rst || sw_rst) begin
			mem_r_n_r1 		 	<= 1;
			mem_ad_rd_r1   	<= {q1_addr_low, 1'b0};
			replay_count_r1 <= q1_replay_count;
    end
    else if(!q1_enable) begin
			mem_r_n_r1 		 	<= 1;
			mem_ad_rd_r1   	<= {q1_addr_low, 1'b0};
			replay_count_r1 <= q1_replay_count;
    end
    else begin
			mem_r_n_r1 			<= 1;
			
			if (enable) begin
				if (cur_qid=='d1) begin
					if (replay_count_r1>0) begin
						if (mem_r_n_r1)
							mem_r_n_r1 <= 0;
				  
						if (mem_ad_rd_r1 >= ({q1_addr_high, 1'b0}-1)) begin
							mem_ad_rd_r1 <= {q1_addr_low, 1'b0};
							replay_count_r1 <= replay_count_r1-1;
						end
						else
							mem_ad_rd_r1 <= mem_ad_rd_r1+1;
					end
				end
			end
    end
  end
	
  always @ (posedge clk) begin
    if(rst || sw_rst) begin
			mem_r_n_r2 		 	<= 1;
			mem_ad_rd_r2   	<= {q2_addr_low, 1'b0};
			replay_count_r2 <= q2_replay_count;
    end
    else if(!q2_enable) begin
			mem_r_n_r2 		 	<= 1;
			mem_ad_rd_r2   	<= {q2_addr_low, 1'b0};
			replay_count_r2 <= q2_replay_count;
    end
    else begin
			mem_r_n_r2 			<= 1;
			
			if (enable) begin
				if (cur_qid=='d2) begin
					if (replay_count_r2>0) begin
						if (mem_r_n_r2)
							mem_r_n_r2 <= 0;
				  
						if (mem_ad_rd_r2 >= ({q2_addr_high, 1'b0}-1)) begin
							mem_ad_rd_r2 <= {q2_addr_low, 1'b0};
							replay_count_r2 <= replay_count_r2-1;
						end
						else
							mem_ad_rd_r2 <= mem_ad_rd_r2+1;
					end
				end
			end
    end
	end
		
  always @ (posedge clk) begin
    if(rst || sw_rst) begin
			mem_r_n_r3 		 	<= 1;
			mem_ad_rd_r3   	<= {q3_addr_low, 1'b0};
			replay_count_r3 <= q3_replay_count;
    end
    else if(!q3_enable) begin
			mem_r_n_r3 		 	<= 1;
			mem_ad_rd_r3   	<= {q3_addr_low, 1'b0};
			replay_count_r3 <= q3_replay_count;
    end
    else begin
			mem_r_n_r3 			<= 1;
			
			if (enable) begin
				if (cur_qid=='d3) begin
					if (replay_count_r3>0) begin
						if (mem_r_n_r3)
							mem_r_n_r3 <= 0;
				  
						if (mem_ad_rd_r3 >= ({q3_addr_high, 1'b0}-1)) begin
							mem_ad_rd_r3 <= {q3_addr_low, 1'b0};
							replay_count_r3 <= replay_count_r3-1;
						end
						else
							mem_ad_rd_r3 <= mem_ad_rd_r3+1;
					end
				end
			end
    end
	end
	
  always @ (posedge clk) begin
    if(rst || sw_rst) begin
			fifo_din_qid 		<= 0;
			fifo_wr_en 			<= 0;
    end
    else begin
			fifo_wr_en 			<= 0;
			
			if (enable) begin
				case (cur_qid)
					'd0: begin
						if (replay_count_r0>0) begin
							fifo_din_qid <= 0;
							fifo_wr_en 	 <= 1;
						end
					end
					'd1: begin
					  if (replay_count_r1>0) begin
							fifo_din_qid <= 1;
							fifo_wr_en 	 <= 1;
						end
					end
					'd2: begin
						if (replay_count_r2>0) begin
							fifo_din_qid <= 2;
							fifo_wr_en 	 <= 1;
						end
					end
					'd3: begin
						if (replay_count_r3>0) begin
							fifo_din_qid <= 3;
							fifo_wr_en 	 <= 1;
						end
					end
					default: begin
						fifo_wr_en 			<= 0;
					end
				endcase
			end
    end
  end
	
	always @ * begin
		mem_r_n   = 1;
		mem_ad_rd = 0;
	
		case (cur_qid)
			'd0: begin
				mem_r_n   = mem_r_n_r0;
				mem_ad_rd = mem_ad_rd_r0[MEM_ADDR_WIDTH:1];
			end
			'd1: begin
				mem_r_n   = mem_r_n_r1;
				mem_ad_rd = mem_ad_rd_r1[MEM_ADDR_WIDTH:1];
			end
			'd2: begin
				mem_r_n   = mem_r_n_r2;
				mem_ad_rd = mem_ad_rd_r2[MEM_ADDR_WIDTH:1];
			end
			'd3: begin
				mem_r_n   = mem_r_n_r3;
				mem_ad_rd = mem_ad_rd_r3[MEM_ADDR_WIDTH:1];
			end
			default: begin
				mem_r_n   = 1;
			end
		endcase
	end

  // --- QID FIFO (Depth of 16 for worst case delay (i.e., 14 cycles) between the read request and qrl_valid)
  fallthrough_small_fifo #(.WIDTH(NUM_QUEUES_BITS), .MAX_DEPTH_BITS(4))
    qid_fifo_inst
      ( .din         (fifo_din_qid),
        .wr_en       (fifo_wr_en),
        .rd_en       (fifo_rd_en),
        .dout        (fifo_dout_qid),
        .full        (),
        .prog_full   (),
        .nearly_full (fifo_full),
        .empty       (fifo_empty),
        .reset       (rst || sw_rst),
        .clk         (clk)
      );
	
	// --- Data logic
  always @ * begin
		fifo_rd_en = mem_qr_valid;
		
		// Note: based on the assumptions that:
		// (1) We always have an entry for a given read data in the FIFO, so it will never be empty.
		// (2) The output FIFOs will have always have space to store the read data. The prog_full is used in the 
		//		 round-robin arbiter above to ensure that we don't overwrite.
  end
	
  always @ (posedge clk) begin
    if(rst || sw_rst) begin
			q0_fifo_wr_en_r0 <= 0;
      q0_fifo_data_r0  <= {FIFO_DATA_WIDTH{1'b0}};
			
			q1_fifo_wr_en_r0 <= 0;
      q1_fifo_data_r0  <= {FIFO_DATA_WIDTH{1'b0}};
			
			q2_fifo_wr_en_r0 <= 0;
      q2_fifo_data_r0  <= {FIFO_DATA_WIDTH{1'b0}};
			
			q3_fifo_wr_en_r0 <= 0;
      q3_fifo_data_r0  <= {FIFO_DATA_WIDTH{1'b0}};
    end
    else begin
			q0_fifo_wr_en_r0 <= 0;
			q1_fifo_wr_en_r0 <= 0;
			q2_fifo_wr_en_r0 <= 0;
			q3_fifo_wr_en_r0 <= 0;
			
			if (mem_qr_valid) begin
				case (fifo_dout_qid) 
					'd0: begin
						q0_fifo_wr_en_r0 <= 1;
						q0_fifo_data_r0  <= {mem_qrh, mem_qrl};
					end
					'd1: begin
						q1_fifo_wr_en_r0 <= 1;
						q1_fifo_data_r0  <= {mem_qrh, mem_qrl};
					end
					'd2: begin
						q2_fifo_wr_en_r0 <= 1;
						q2_fifo_data_r0  <= {mem_qrh, mem_qrl};
					end
					'd3: begin
						q3_fifo_wr_en_r0 <= 1;
						q3_fifo_data_r0  <= {mem_qrh, mem_qrl};
					end
					default: begin
						q0_fifo_wr_en_r0 <= 0;
						q1_fifo_wr_en_r0 <= 0;
						q2_fifo_wr_en_r0 <= 0;
						q3_fifo_wr_en_r0 <= 0;
					end
				endcase
			end
    end
  end
	
  always @ (posedge clk) begin
		q0_fifo_wr_en_r1 <= q0_fifo_wr_en_r0;
    q0_fifo_data_r1  <= q0_fifo_data_r0;
		q0_fifo_wr_en 	 <= q0_fifo_wr_en_r1;
    q0_fifo_data  	 <= q0_fifo_data_r1;
		
		q1_fifo_wr_en_r1 <= q1_fifo_wr_en_r0;
    q1_fifo_data_r1  <= q1_fifo_data_r0;
		q1_fifo_wr_en 	 <= q1_fifo_wr_en_r1;
    q1_fifo_data  	 <= q1_fifo_data_r1;
		
		q2_fifo_wr_en_r1 <= q2_fifo_wr_en_r0;
    q2_fifo_data_r1  <= q2_fifo_data_r0;
		q2_fifo_wr_en 	 <= q2_fifo_wr_en_r1;
    q2_fifo_data  	 <= q2_fifo_data_r1;
		
		q3_fifo_wr_en_r1 <= q3_fifo_wr_en_r0;
    q3_fifo_data_r1  <= q3_fifo_data_r0;
		q3_fifo_wr_en 	 <= q3_fifo_wr_en_r1;
    q3_fifo_data  	 <= q3_fifo_data_r1;
  end
	
endmodule

