/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        WHEN_NO_HIT.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_monitoring_output_port_lookup_v1_00_a
 *
 *  Module:
 *        WHEN_NO_HIT
 *
 *  Author:
 *        Muhammad Shahbaz, Gianni Antichi
 *
 *  Description:
 *        Hardwire the hardware interfaces to CPU and vice versa
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

`include "../defines.vh"



	module WHEN_NO_HIT
        #(
                parameter C_S_AXIS_DATA_WIDTH  = 256,
                parameter C_S_AXIS_TUSER_WIDTH = 128,
                parameter TUPLE_WIDTH          = 104,
                parameter NUM_INPUT_QUEUES     = 8,
                parameter PRTCL_ID_WIDTH       = 2,
                parameter SRC_PORT_POS         = 16,
                parameter BYTES_COUNT_WIDTH    = 16,
                parameter ATTRIBUTE_DATA_WIDTH  = 135
        )
        (// --- Interface to the previous stage
                input [C_S_AXIS_DATA_WIDTH-1:0] in_tdata,
                input [C_S_AXIS_TUSER_WIDTH-1:0]in_tuser,
                input                           in_valid,
                input                           in_tlast,
                input                           in_eoh,

        // --- Results 
        	output reg                      pkt_valid,
        	output [ATTRIBUTE_DATA_WIDTH-1:0]pkt_attributes,

        // --- Misc
        	input				reset,
       		input				clk
        );

	//------------------ Internal Parameter ---------------------------

        localparam NUM_STATES   = 3;
        localparam WAIT_PKT     = 1;
        localparam PKT_WAIT_HDR = 2;
        localparam PKT_WAIT_EOP = 4;

        localparam IP_WIDTH     = 32;
        localparam PORT_WIDTH   = 16;
        localparam PROTO_WIDTH  = 8;

        localparam PROTO_OFFSET                 = 0;
        localparam IP_SRC_OFFSET                = PROTO_WIDTH;
        localparam IP_DST_OFFSET                = IP_SRC_OFFSET + IP_WIDTH;
        localparam PORT_SRC_OFFSET              = IP_DST_OFFSET + IP_WIDTH;
        localparam PORT_DST_OFFSET              = PORT_SRC_OFFSET + PORT_WIDTH;
        localparam BYTES_COUNT_OFFSET           = PORT_DST_OFFSET + PORT_WIDTH;
        localparam PKT_FLAGS_OFFSET             = BYTES_COUNT_OFFSET + BYTES_COUNT_WIDTH;
        localparam PRTCL_ID_OFFSET              = PKT_FLAGS_OFFSET + `PKT_FLAGS;
        localparam NUM_INPUT_QUEUES_OFFSET      = PRTCL_ID_OFFSET + PRTCL_ID_WIDTH;

	//---------------------- Wires/Regs -------------------------------
	
        reg [C_S_AXIS_DATA_WIDTH-1:0]   in_tdata_d0;
        reg [C_S_AXIS_TUSER_WIDTH-1:0]  in_tuser_d0;
        reg                             in_valid_d0;
        reg                             in_tlast_d0;
        reg                             in_eoh_d0;

        reg [NUM_INPUT_QUEUES-1:0]      pkt_input_if;
        reg [BYTES_COUNT_WIDTH-1:0]     pkt_bytes;
        reg [`PKT_FLAGS-1:0]            pkt_flags;

        reg                             pkt_valid_w;
        reg [NUM_INPUT_QUEUES-1:0]      pkt_input_if_w;
        reg [BYTES_COUNT_WIDTH-1:0]     pkt_bytes_w;
        reg [`PKT_FLAGS-1:0]            pkt_flags_w;


        reg [NUM_STATES-1:0]            cur_state;
        reg [NUM_STATES-1:0]            nxt_state;

	//------------------------ Logic ----------------------------------
	 
        always @(posedge clk or posedge reset) begin
                if (reset) begin
                        in_valid_d0 <= 1'b0;
                        in_tlast_d0 <= 1'b0;
                        in_eoh_d0   <= 1'b0;
                end
                else begin
                        in_valid_d0 <= in_valid;
                        in_tlast_d0 <= in_tlast;
                        in_eoh_d0   <= in_eoh;
                end
         end

        always @(posedge clk) begin
                in_tdata_d0 <= in_tdata;
                in_tuser_d0 <= in_tuser;

        end
	
	always @ (*) begin  
		nxt_state = cur_state;
		pkt_valid_w = 1'b0;
                pkt_flags_w = pkt_flags;
		pkt_input_if_w = pkt_input_if;
                pkt_bytes_w = pkt_bytes;

		case (cur_state)		 		
	 	

		WAIT_PKT: begin
			pkt_input_if_w = {NUM_INPUT_QUEUES{1'b0}};
			pkt_bytes_w = {BYTES_COUNT_WIDTH{1'b0}};
                        pkt_flags_w = {`PKT_FLAGS{1'b0}};
			
			if(in_valid_d0) begin
				pkt_input_if_w = in_tuser_d0[SRC_PORT_POS+NUM_INPUT_QUEUES-1:SRC_PORT_POS];
				pkt_bytes_w = in_tuser_d0[15:0];
                                pkt_flags_w[`PKT_FLG_VLAN_Q] = (in_tdata_d0[159:144] == `ETH_VLAN_Q);
                                pkt_flags_w[`PKT_FLG_VLAN_AD] = (in_tdata_d0[159:144] == `ETH_VLAN_AD);
                                if(pkt_flags_w[`PKT_FLG_VLAN_Q])
                                        pkt_flags_w[`PKT_FLG_IPv4] = (in_tdata_d0[127:112] == `ETH_IP);
                                else if(pkt_flags_w[`PKT_FLG_VLAN_AD])
                                        pkt_flags_w[`PKT_FLG_IPv4] = (in_tdata_d0[95:80] == `ETH_IP);
                                nxt_state = PKT_WAIT_HDR;
			end
		end
	 		
	
                PKT_WAIT_HDR: begin
                        if (in_valid_d0) begin
                                if (in_tlast_d0) begin /*small pkt*/
                                        pkt_valid_w = 1'b1;
                                        nxt_state = WAIT_PKT;
                                end
                                else if (in_eoh_d0) begin
                                        pkt_valid_w = 1'b1;
                                        nxt_state = PKT_WAIT_EOP;
                                end
                        end
                end

                PKT_WAIT_EOP: begin
                        if (in_valid_d0 && in_tlast_d0)
                                nxt_state = WAIT_PKT;
                end
        	endcase
        end
 
	 
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			cur_state <= WAIT_PKT;

			pkt_valid <= 1'b0;	 			
			pkt_input_if <= {NUM_INPUT_QUEUES{1'b0}};
                        pkt_bytes <= {BYTES_COUNT_WIDTH{1'b0}};
			pkt_flags <= {`PKT_FLAGS{1'b0}};
	 	end
	 	else begin
	 		cur_state <= nxt_state;
	 		
	 		pkt_valid <= pkt_valid_w;	 	
			pkt_input_if <= pkt_input_if_w;
                        pkt_bytes <= pkt_bytes_w;
			pkt_flags <= pkt_flags_w;
		end
	end           
	

        assign pkt_attributes[(PROTO_WIDTH+PROTO_OFFSET)-1:PROTO_OFFSET]                                        = {PROTO_WIDTH{1'b0}};
        assign pkt_attributes[(IP_WIDTH+IP_SRC_OFFSET)-1:IP_SRC_OFFSET]                                         = {IP_WIDTH{1'b0}};
        assign pkt_attributes[(IP_WIDTH+IP_DST_OFFSET)-1:IP_DST_OFFSET]                                         = {IP_WIDTH{1'b0}};
        assign pkt_attributes[(PORT_WIDTH+PORT_SRC_OFFSET)-1:PORT_SRC_OFFSET]                                   = {PORT_WIDTH{1'b0}};
        assign pkt_attributes[(PORT_WIDTH+PORT_DST_OFFSET)-1:PORT_DST_OFFSET]                                   = {PORT_WIDTH{1'b0}};
        assign pkt_attributes[(BYTES_COUNT_WIDTH+BYTES_COUNT_OFFSET)-1:BYTES_COUNT_OFFSET]                      = pkt_bytes;
        assign pkt_attributes[(`PKT_FLAGS+PKT_FLAGS_OFFSET)-1:PKT_FLAGS_OFFSET]                                 = pkt_flags;
        assign pkt_attributes[(PRTCL_ID_WIDTH+PRTCL_ID_OFFSET)-1:PRTCL_ID_OFFSET]                               = `PRIORITY_WHEN_NO_HIT;
        assign pkt_attributes[(NUM_INPUT_QUEUES+NUM_INPUT_QUEUES_OFFSET)-1:NUM_INPUT_QUEUES_OFFSET]             = pkt_input_if;
	
	endmodule
