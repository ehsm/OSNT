/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        timestamp_insertion.v
 *
 *  Library:
 *        hw/std/pcores/nf10_10g_interface_v1_11_a
 *
 *  Module:
 *        timestamp_insertion
 *
 *  Author:
 *        Gianni Antichi
 *
 *  Description:
 *        Timestamp insertion
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

module timestamp_insertion
#(
   parameter TIMESTAMP_WIDTH = 64,
   parameter C_M_AXIS_DATA_WIDTH = 256,
   parameter C_M_AXIS_TUSER_WIDTH = 128
)
(
	
   output reg [C_M_AXIS_DATA_WIDTH-1:0]  m_axis_tdata,
   output reg [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
   output reg [C_M_AXIS_DATA_WIDTH/8-1:0]m_axis_tstrb,
   output reg			     m_axis_tvalid,
   output reg			     m_axis_tlast,
   input			     m_axis_tready,

   input [TIMESTAMP_WIDTH-1:0]	    stamp_counter,
   input			    pkt_start,

   input [C_M_AXIS_DATA_WIDTH-1:0]  s_axis_tdata,
   input [C_M_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
   input [C_M_AXIS_DATA_WIDTH/8-1:0]s_axis_tstrb,
   input                            s_axis_tvalid,
   input                            s_axis_tlast,
   output                           s_axis_tready,

   input			    reset,
   input			    clk
 
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



  localparam TIMESTAMP = 32;
  localparam WAIT = 1;
  localparam SEND_PACKET = 2;
  localparam MAX_PKT_RX_QUEUE = 66;
  localparam IN_TIME_DEPTH_BIT = log2(MAX_PKT_RX_QUEUE);

 
  wire timestamp_fifo_nearly_full;
  wire timestamp_fifo_empty;
  reg  timestamp_fifo_rd_en;
  reg  in_fifo_rd_en;
  wire in_fifo_empty;
  wire in_fifo_nearly_full;

  wire [TIMESTAMP_WIDTH-1:0] fifo_timestamp;

  wire [C_M_AXIS_TUSER_WIDTH-1:0]      tuser_fifo;
  wire [((C_M_AXIS_DATA_WIDTH / 8))-1:0] tstrb_fifo;
  wire                                 tlast_fifo;
  wire [C_M_AXIS_DATA_WIDTH-1:0]        tdata_fifo;

  reg[1:0] state,state_next;

  assign s_axis_tready = !in_fifo_nearly_full;


  fallthrough_small_fifo #(.WIDTH(C_M_AXIS_DATA_WIDTH+C_M_AXIS_TUSER_WIDTH+C_M_AXIS_DATA_WIDTH/8+1), .MAX_DEPTH_BITS(2))
      input_fifo
        (.din ({s_axis_tlast, s_axis_tuser, s_axis_tstrb, s_axis_tdata}),     // Data in
         .wr_en (s_axis_tvalid & ~in_fifo_nearly_full),               // Write enable
         .rd_en (in_fifo_rd_en),       // Read the next word
         .dout ({tlast_fifo, tuser_fifo, tstrb_fifo, tdata_fifo}),
         .full (),
         .prog_full (),
         .nearly_full (in_fifo_nearly_full),
         .empty (in_fifo_empty),
         .reset (reset),
         .clk (clk)
         );


   fallthrough_small_fifo
      #( .WIDTH(TIMESTAMP_WIDTH),
         .MAX_DEPTH_BITS(IN_TIME_DEPTH_BIT)
       ) timestamp_fifo
       (
       // Outputs
       .dout  (fifo_timestamp),
       .full  (),
       .nearly_full (timestamp_fifo_nearly_full),
       .prog_full (),
       .empty (timestamp_fifo_empty),
       // Inputs
       .din (stamp_counter),
       .wr_en (pkt_start),
       .rd_en (timestamp_fifo_rd_en),
       .reset (reset),
       .clk (clk)
       );


   always @(*) begin
      m_axis_tuser = tuser_fifo;
      m_axis_tstrb = tstrb_fifo;
      m_axis_tlast = tlast_fifo;
      m_axis_tdata = tdata_fifo;
      m_axis_tvalid = 0;

      in_fifo_rd_en = 0;
      timestamp_fifo_rd_en = 0;

      state_next = state;

      case(state)
        WAIT: begin
           if(!timestamp_fifo_empty && !in_fifo_empty) begin
		m_axis_tvalid = 1;
		m_axis_tuser[TIMESTAMP+TIMESTAMP_WIDTH-1:TIMESTAMP] = fifo_timestamp;
		if(m_axis_tready) begin
			in_fifo_rd_en = 1;
			timestamp_fifo_rd_en = 1;
                	state_next = SEND_PACKET;
		end
           end
        end

        SEND_PACKET: begin
           if(!in_fifo_empty) begin
		m_axis_tvalid = 1;
		if(m_axis_tready) begin
                	in_fifo_rd_en = 1;
                	if(tlast_fifo)
                		state_next=WAIT;
		end
            end
        end

      endcase
   end


   always @(posedge clk) begin
      if(reset) begin
         state <= WAIT;
      end
      else begin
         state <= state_next;
      end
   end





endmodule
