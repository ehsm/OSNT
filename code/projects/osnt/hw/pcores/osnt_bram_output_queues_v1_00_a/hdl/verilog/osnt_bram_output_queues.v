/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        nf10_bram_output_queues.v
 *
 *  Library:
 *        hw/std/pcores/nf10_bram_output_queues_v1_00_a
 *
 *  Module:
 *        nf10_bram_output_queues
 *
 *  Author:
 *        James Hongyi Zeng
 *
 *  Description:
 *        BRAM Output queues
 *        Outputs have a parameterizable width
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

module osnt_bram_output_queues
#(
    // Master AXI Stream Data Width
    parameter C_M_AXIS_DATA_WIDTH=256,
    parameter C_S_AXIS_DATA_WIDTH=256,
    parameter C_M_AXIS_TUSER_WIDTH=128,
    parameter C_S_AXIS_TUSER_WIDTH=128
)
(
    // Part 1: System side signals
    // Global Ports
    input axi_aclk,
    input axi_resetn,

    // Slave Stream Ports (interface to data path)
    input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tstrb,
    input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input s_axis_tvalid,
    output reg s_axis_tready,
    input s_axis_tlast,

    // Master Stream Ports (interface to TX queues)
    output [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tstrb,
    output [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
    output  m_axis_tvalid,
    input m_axis_tready,
    output  m_axis_tlast
);

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2

   // ------------ Internal Params --------


   localparam BUFFER_SIZE         = 4096; // Buffer size 4096B
   localparam BUFFER_SIZE_WIDTH   = log2(BUFFER_SIZE/(C_M_AXIS_DATA_WIDTH/8));

   localparam MAX_PACKET_SIZE = 1600;
   localparam BUFFER_THRESHOLD = (BUFFER_SIZE-MAX_PACKET_SIZE)/(C_M_AXIS_DATA_WIDTH/8);

   localparam NUM_STATES = 3;
   localparam IDLE = 0;
   localparam WR_PKT = 1;
   localparam DROP = 2;

   localparam NUM_METADATA_STATES = 2;
   localparam WAIT_HEADER = 0;
   localparam WAIT_EOP = 1;

   // ------------- Regs/ wires -----------

   reg 		nearly_full;
   wire		nearly_full_fifo;
   wire		empty;

   reg		metadata_nearly_full;
   wire		metadata_nearly_full_fifo;
   wire		metadata_empty;

   wire [C_M_AXIS_TUSER_WIDTH-1:0]	fifo_out_tuser;
   wire [C_M_AXIS_DATA_WIDTH-1:0]	fifo_out_tdata;
   wire [((C_M_AXIS_DATA_WIDTH/8))-1:0]	fifo_out_tstrb;
   wire					fifo_out_tlast;

   wire		rd_en;
   reg		wr_en;

   reg		metadata_rd_en;
   reg		metadata_wr_en;

   wire [NUM_QUEUES-1:0]      	oq;

   reg [NUM_STATES-1:0]		state;
   reg [NUM_STATES-1:0]         state_next;

   reg [NUM_METADATA_STATES-1:0]metadata_state;
   reg [NUM_METADATA_STATES-1:0]metadata_state_next;

   reg		first_word, first_word_next;

   // ------------ Modules -------------

      fallthrough_small_fifo
        #( .WIDTH(C_M_AXIS_DATA_WIDTH+C_M_AXIS_DATA_WIDTH/8+1),
           .MAX_DEPTH_BITS(BUFFER_SIZE_WIDTH),
           .PROG_FULL_THRESHOLD(BUFFER_THRESHOLD))
      output_fifo
        (// Outputs
         .dout                           ({fifo_out_tlast, fifo_out_tstrb, fifo_out_tdata}),
         .full                           (),
         .nearly_full                    (),
	 .prog_full                      (nearly_full_fifo),
         .empty                          (empty),
         // Inputs
         .din                            ({s_axis_tlast, s_axis_tstrb, s_axis_tdata}),
         .wr_en                          (wr_en),
         .rd_en                          (rd_en),
         .reset                          (~axi_resetn),
         .clk                            (axi_aclk));

      fallthrough_small_fifo
        #( .WIDTH(C_M_AXIS_TUSER_WIDTH),
           .MAX_DEPTH_BITS(2))
      metadata_fifo
        (// Outputs
         .dout                           (fifo_out_tuser),
         .full                           (),
         .nearly_full                    (metadata_nearly_full_fifo),
	 .prog_full                      (),
         .empty                          (metadata_empty),
         // Inputs
         .din                            (s_axis_tuser),
         .wr_en                          (metadata_wr_en),
         .rd_en                          (metadata_rd_en),
         .reset                          (~axi_resetn),
         .clk                            (axi_aclk));

   always @(metadata_state, rd_en, fifo_out_tlast) begin
        metadata_rd_en = 1'b0;
        metadata_state_next = metadata_state;
      	case(metadata_state)
      		WAIT_HEADER: begin
      			if(rd_en) begin
      				metadata_state_next = WAIT_EOP;
      				metadata_rd_en = 1'b1;
      			end
      		end
      		WAIT_EOP: begin
      			if(rd_en & fifo_out_tlast) begin
      				metadata_state_next = WAIT_HEADER;
      			end
      		end
        endcase
      end

      always @(posedge axi_aclk) begin
      	if(~axi_resetn) begin
         	metadata_state <= WAIT_HEADER;
      	end
      	else begin
         	metadata_state <= metadata_state_next;
      	end
      end
   end
   endgenerate

   // Per NetFPGA-10G AXI Spec
   localparam DST_POS = 24;
   assign oq = s_axis_tuser[DST_POS] |
   			   (s_axis_tuser[DST_POS + 2] << 1) |
   			   (s_axis_tuser[DST_POS + 4] << 2) |
   			   (s_axis_tuser[DST_POS + 6] << 3) |
   			   ((s_axis_tuser[DST_POS + 1] | s_axis_tuser[DST_POS + 3] | s_axis_tuser[DST_POS + 5] | s_axis_tuser[DST_POS + 7]) << 4);

   always @(*) begin
      state_next     = state;
      wr_en          = 0;
      metadata_wr_en = 0;
      s_axis_tready  = 0;
      first_word_next = first_word;

      case(state)

        /* cycle between input queues until one is not empty */
        IDLE: begin
           if(s_axis_tvalid) begin
              if(~|((nearly_full | metadata_nearly_full) & oq)) begin // All interesting oqs are NOT _nearly_ full (able to fit in the maximum pacekt).
                  state_next = WR_PKT;
                  first_word_next = 1'b1;
              end
              else begin
              	  state_next = DROP;
              end
           end
        end

        /* wait until eop */
        WR_PKT: begin
           s_axis_tready = 1;
           if(s_axis_tvalid) begin
           	first_word_next = 1'b0;
		wr_en = 1;
		if(first_word) begin
			metadata_wr_en = 1;
		end
		if(s_axis_tlast) begin
			state_next = IDLE;
		end
           end
        end // case: WR_PKT

        DROP: begin
           s_axis_tready = 1;
           if(s_axis_tvalid & s_axis_tlast) begin
           	  state_next = IDLE;
           end
        end

      endcase // case(state)
   end // always @ (*)



   always @(posedge axi_aclk) begin
      if(~axi_resetn) begin
         state <= IDLE;
         first_word <= 0;
      end
      else begin
         state <= state_next;
         first_word <= first_word_next;
      end

      nearly_full <= nearly_full_fifo;
      metadata_nearly_full <= metadata_nearly_full_fifo;
   end


   assign m_axis_tdata	 = fifo_out_tdata;
   assign m_axis_tstrb	 = fifo_out_tstrb;
   assign m_axis_tuser	 = fifo_out_tuser;
   assign m_axis_tlast	 = fifo_out_tlast;
   assign m_axis_tvalid	 = ~empty;
   assign rd_en	 	 = m_axis_tready & ~empty;


endmodule
