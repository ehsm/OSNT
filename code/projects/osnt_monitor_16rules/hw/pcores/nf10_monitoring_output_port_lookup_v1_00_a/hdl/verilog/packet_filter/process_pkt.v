/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        process_pkt.v
 *
 *  Library:
 *        /hw/contrib/pcores/nf10_monitoring_output_port_lookup_v1_10_a
 *
 *  Module:
 *        process_pkt
 *
 *  Author:
 *        Gianni Antichi
 *
 *  Description:
 *        TCAM lookup module
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

`timescale 1ns/1ps

module process_pkt
    #(parameter TUPLE_WIDTH = 104,
      parameter NUM_QUEUES = 8,
      parameter MON_LUT_DEPTH_BITS = 5)
   (  // --- trigger signals
      input [TUPLE_WIDTH-1:0]   tuple,
      input [NUM_QUEUES-1:0]    src_port,
      input		        lookup_req,

      // --- output signal
      output reg [NUM_QUEUES-1:0]dst_ports,
      output reg	        lookup_done,

      // --- interface to registers
      input [MON_LUT_DEPTH_BITS-1:0]rule_rd_addr,          // address in table to read
      input                     rule_rd_req,           // request a read
      output [TUPLE_WIDTH-1:0]  rule_rd,               // rule to match in the TCAM
      output [TUPLE_WIDTH-1:0]  rule_rd_mask,          // rule subnet
      output reg                rule_rd_ack,           // pulses high

      input [MON_LUT_DEPTH_BITS-1:0]rule_wr_addr,
      input                     rule_wr_req,
      input [TUPLE_WIDTH-1:0]   rule_wr,
      input [TUPLE_WIDTH-1:0]   rule_wr_mask,
      output reg                rule_wr_ack,
   
      // --- misc
      input                     clk,
      input                     reset
     );

   //--------------------- Internal Parameter-------------------------
      localparam RESET = 0;
      localparam READY = 1;
      localparam MON_DEPTH = 2**MON_LUT_DEPTH_BITS;
      localparam CMP_WIDTH = TUPLE_WIDTH;
      localparam RESET_CMP_DATA = {CMP_WIDTH{1'b0}};
      localparam RESET_CMP_DMASK = {CMP_WIDTH{1'b0}};

      localparam NOT_MATCH_PORT = {NUM_QUEUES{1'b0}};
   //---------------------- Wires and regs----------------------------

      reg [MON_LUT_DEPTH_BITS-1:0]  lut_rd_addr;
      reg [2*CMP_WIDTH-1:0]     lut_rd_data;

      reg [2*CMP_WIDTH-1:0]     lut[MON_DEPTH-1:0];

      reg                       lookup_latched;
      reg                       rd_req_latched;

      reg [CMP_WIDTH-1:0]       din;
      reg [CMP_WIDTH-1:0]	data_mask;

      reg			we;
      reg [MON_LUT_DEPTH_BITS-1:0]  wr_addr;


      wire [CMP_WIDTH-1:0]      cam_din;
      wire [CMP_WIDTH-1:0]      cam_data_mask;
      wire [MON_LUT_DEPTH_BITS-1:0] cam_wr_addr;

      reg [NUM_QUEUES-1:0]      match_oport;
      reg [NUM_QUEUES-1:0]      dst_port_latched;

      reg [4:0]                 reset_count;
      reg                       state;
 
   //------------------------- Modules-------------------------------

   // 1 cycle read latency, 16 cycles write latency
   tcam16
     mon_tcam
     (
      // Outputs
      .BUSY	 	(cam_busy),
      .MATCH     	(cam_match),
      .MATCH_ADDR	(),
      // Inputs
      .CLK	 	(clk),
      .CMP_DIN   	(tuple),
      .DIN	 	(cam_din),
      .CMP_DATA_MASK	(104'h0),
      .DATA_MASK	(cam_data_mask),
      .WE		(cam_we),
      .WR_ADDR		(cam_wr_addr));
  


   //------------------------- Logic --------------------------------

   assign rule_rd       = lut_rd_data[CMP_WIDTH-1:0];
   assign rule_rd_mask  = lut_rd_data[2*CMP_WIDTH-1:CMP_WIDTH];

   assign cam_din 	= din;
   assign cam_data_mask = data_mask;

   assign cam_we	= we;
   assign cam_wr_addr   = wr_addr;


   /* if we get a miss then set the dst port to the default ports
    * without the source */


   always @(*) begin
        match_oport = 0;
        case(src_port)
                8'h1: 	match_oport     = 8'h2;
                8'h4: 	match_oport     = 8'h8;
                8'h10:	match_oport     = 8'h20;
                8'h40:	match_oport     = 8'h80;
                default:match_oport     = 8'h0;
        endcase
   end


   always @(posedge clk) begin
      
      if(reset) begin
         lookup_latched     <= 0;
         lookup_done        <= 0;
         rd_req_latched     <= 0;
         we                 <= 0;
         wr_addr            <= 0;
         din                <= 0;
         data_mask          <= 0;
	 dst_ports	    <= 0;

         rule_wr_ack        <= 0;
         state              <= RESET;
         reset_count        <= 0;

      end // if (reset)
      else begin
         if (state == RESET && !cam_busy) begin
            if(reset_count == 16) begin
               state  <= READY;
               we     <= 1'b0;
            end
            else begin
                we           <= 1'b1;
		wr_addr      <= reset_count[3:0];
                din          <= RESET_CMP_DATA;
                data_mask    <= RESET_CMP_DMASK;
                reset_count  <= reset_count + 1'b1;
            end
         end
         
	else if (state == READY) begin
	/* first pipeline stage -- do CAM lookup */
		lookup_latched              <= lookup_req;
	   	dst_port_latched		<= match_oport;
            
        /* second pipeline stage -- CAM result */
           	dst_ports             	<= ((lookup_latched & cam_match)) ? dst_port_latched : NOT_MATCH_PORT;
           //dst_ports			<= (lookup_req) ? port_out : dst_ports;
           //dst_ports                   <= (lookup_req & cam_match) ? match_oport : not_match_oport;
           //lookup_done			<= lookup_req;
	   	lookup_done                 <= lookup_latched;

           /* handle read LUT */
           	lut_rd_addr                 <= rule_rd_addr;
           	rd_req_latched              <= rule_rd_req;
            
           /* output read LUT */
           	lut_rd_data                 <= lut[lut_rd_addr];
           	rule_rd_ack                 <= rd_req_latched;
            
           /* Handle writes */
           	if(rule_wr_req && !cam_busy) begin
			wr_addr    <= rule_wr_addr[3:0];
                 	din        <= rule_wr;
                 	data_mask  <= rule_wr_mask;
                 	rule_wr_ack    <= 1;
		        we <= 1;
           	end  
           	else begin
               		we <= 0;
               		rule_wr_ack <= 0;
            	end // else: !if(rule_wr_req && !cam_busy)
         end // else: !if(state == RESET)
         
	end // else: !if(reset)

      // separate this out to allow implementation as BRAM
      	if(we)
		lut[{1'b0, wr_addr[3:0]}] <= {cam_data_mask, cam_din};
   end // always @ (posedge clk)


endmodule // process_pkt

