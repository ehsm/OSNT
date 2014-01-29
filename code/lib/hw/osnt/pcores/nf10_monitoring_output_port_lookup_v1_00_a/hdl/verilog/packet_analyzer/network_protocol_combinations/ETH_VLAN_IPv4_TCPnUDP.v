/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        ETH_VLAN_IPv4_TCPnUDP.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_monitoring_output_port_lookup_v1_00_a
 *
 *  Module:
 *        ETH_VLAN_IPv4_TCPnUDP
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

	module ETH_VLAN_IPv4_TCPnUDP
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
    		input [C_S_AXIS_DATA_WIDTH-1:0]	in_tdata,
                input [C_S_AXIS_TUSER_WIDTH-1:0]in_tuser,
    		input				in_valid,
    		input				in_tlast,
    		input				in_eoh,
    
    	// --- Results 
    		output reg			pkt_valid,
   		output [ATTRIBUTE_DATA_WIDTH-1:0]pkt_attributes,
    
    	// --- Misc
    		input                           reset,
    		input                           clk 
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

	 
	//------------------ Internal Parameter ---------------------------
	
        localparam NUM_STATES   = 4;
        localparam WAIT_PKT     = 1;
        localparam PKT_WORD1    = 2;
        localparam PKT_WAIT_HDR = 4;
        localparam PKT_WAIT_EOP = 8;

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

        reg [3:0]                       pkt_ip_hdr_len;
        reg [IP_WIDTH-1:0]              pkt_src_ip;
        reg [IP_WIDTH-1:0]              pkt_dst_ip;
        reg [PORT_WIDTH-1:0]            pkt_src_port;
        reg [PORT_WIDTH-1:0]            pkt_dst_port;
        reg [PROTO_WIDTH-1:0]           pkt_l4_proto;
        reg [`PKT_FLAGS-1:0]            pkt_flags;
        reg [NUM_INPUT_QUEUES-1:0]      pkt_input_if;
        reg [BYTES_COUNT_WIDTH-1:0]     pkt_bytes;

        reg                             pkt_valid_w;
        reg [3:0]                       pkt_ip_hdr_len_w;
        reg [IP_WIDTH-1:0]              pkt_src_ip_w;
        reg [IP_WIDTH-1:0]              pkt_dst_ip_w;
        reg [PORT_WIDTH-1:0]            pkt_src_port_w;
        reg [PORT_WIDTH-1:0]            pkt_dst_port_w;
        reg [PROTO_WIDTH-1:0]           pkt_l4_proto_w;
        reg [`PKT_FLAGS-1:0]            pkt_flags_w;
        reg [NUM_INPUT_QUEUES-1:0]      pkt_input_if_w;
        reg [BYTES_COUNT_WIDTH-1:0]     pkt_bytes_w;

        reg [NUM_STATES-1:0]            cur_state;
        reg [NUM_STATES-1:0]            nxt_state;


	//------------------------ Logic ----------------------------------
	 
	always @ (posedge clk or posedge reset) begin
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
	 
	always @ (posedge clk) begin
                in_tdata_d0 <= in_tdata;
                in_tuser_d0 <= in_tuser;
	end
	 
	 
	always @ (*) begin  
                nxt_state = cur_state;
                pkt_valid_w = 1'b0;
                pkt_ip_hdr_len_w = pkt_ip_hdr_len;
                pkt_src_ip_w = pkt_src_ip;
                pkt_dst_ip_w = pkt_dst_ip;
                pkt_src_port_w = pkt_src_port;
                pkt_dst_port_w = pkt_dst_port;
                pkt_flags_w = pkt_flags;
                pkt_bytes_w = pkt_bytes;
                pkt_input_if_w = pkt_input_if;
                pkt_l4_proto_w = pkt_l4_proto;
	 		
	 	case (cur_state)		 		
	 	
		WAIT_PKT: begin 			
                        pkt_ip_hdr_len_w = 4'b0;
                        pkt_src_ip_w = {IP_WIDTH{1'b0}};
                        pkt_dst_ip_w = {IP_WIDTH{1'b0}};
                        pkt_src_port_w = {PORT_WIDTH{1'b0}};
                        pkt_dst_port_w = {PORT_WIDTH{1'b0}};
                        pkt_flags_w = {`PKT_FLAGS{1'b0}};
                        pkt_l4_proto_w = {PROTO_WIDTH{1'b0}};
                        pkt_input_if_w = {NUM_INPUT_QUEUES{1'b0}};
                        pkt_bytes_w = {BYTES_COUNT_WIDTH{1'b0}};
	
	 		if (in_valid_d0) begin
                                pkt_input_if_w = in_tuser_d0[SRC_PORT_POS+NUM_INPUT_QUEUES-1:SRC_PORT_POS];
                                pkt_bytes_w = in_tuser_d0[15:0];
                                pkt_flags_w[`PKT_FLG_VLAN_Q] = (in_tdata_d0[159:144] == `ETH_VLAN_Q);
                                pkt_flags_w[`PKT_FLG_VLAN_AD] = (in_tdata_d0[159:144] == `ETH_VLAN_AD);
                        	if(pkt_flags_w[`PKT_FLG_VLAN_Q]) begin
					pkt_flags_w[`PKT_FLG_IPv4] = (in_tdata_d0[127:112] == `ETH_IP);
                                	if(pkt_flags_w[`PKT_FLG_IPv4]) begin
                                        	pkt_ip_hdr_len_w = in_tdata_d0[107:104];
                                        	//pkt_flags_w[`PKT_FLG_FRG] = (in_tdata_d0[62] || (in_tdata_d0[61:48] != 13'd0));
                                        	pkt_flags_w[`PKT_FLG_TCP] = (in_tdata_d0[39:32] == `IP_TCP);
                                        	pkt_flags_w[`PKT_FLG_UDP] = (in_tdata_d0[39:32] == `IP_UDP);
                                        	pkt_l4_proto_w = in_tdata_d0[39:32];
                                        	pkt_src_ip_w = {in_tdata_d0[15:0], pkt_src_ip[15:0]};
                                        	nxt_state = PKT_WORD1;
                                	end
                                	else
                                        	nxt_state = WAIT_PKT;
				end
				else if(pkt_flags_w[`PKT_FLG_VLAN_AD]) begin
					pkt_flags_w[`PKT_FLG_IPv4] = (in_tdata_d0[95:80] == `ETH_IP);
                                        if(pkt_flags_w[`PKT_FLG_IPv4]) begin
                                                pkt_ip_hdr_len_w = in_tdata_d0[75:72];
                                                //pkt_flags_w[`PKT_FLG_FRG] = (in_tdata_d0[30] || (in_tdata_d0[29:16] != 13'd0));
                                                pkt_flags_w[`PKT_FLG_TCP] = (in_tdata_d0[7:0] == `IP_TCP);
                                                pkt_flags_w[`PKT_FLG_UDP] = (in_tdata_d0[7:0] == `IP_UDP);
                                                pkt_l4_proto_w = in_tdata_d0[7:0];
                                                nxt_state = PKT_WORD1;
                                        end
                                        else
                                                nxt_state = WAIT_PKT;
                                end
				else
					nxt_state = WAIT_PKT;
	 		end
		end

	 		
	 	PKT_WORD1: begin
			if(in_valid_d0) begin
				if(pkt_flags_w[`PKT_FLG_VLAN_Q]) begin
					pkt_src_ip_w = {pkt_src_ip[31:16], in_tdata_d0[255:240]};
                                        pkt_dst_ip_w = in_tdata_d0[239:208];
					if (pkt_flags[`PKT_FLG_TCP] || pkt_flags[`PKT_FLG_UDP]) begin
                                        	case(pkt_ip_hdr_len)

                                        	4'd5: begin
                                                	pkt_src_port_w = in_tdata_d0[207:192];
                                                	pkt_dst_port_w = in_tdata_d0[191:176];
                                                	if (in_tlast_d0) begin //small pkt//
                                                        	pkt_valid_w = 1'b1;
                                                        	nxt_state = WAIT_PKT;
                                                	end
                                                	else
                                                        	nxt_state = PKT_WAIT_HDR;
                                        	end

                                        	default: begin //  TO DO case of IP OPTIONS
                                                	//pkt_src_port_w = {PORT_WIDTH{1'b0}};
                                                	//pkt_dst_port_w = {PORT_WIDTH{1'b0}};
                                                	if (in_tlast_d0) begin //small pkt//
                                                        	pkt_valid_w = 1'b1;
                                                        	nxt_state = WAIT_PKT;
                                                	end
                                                	else
                                                        	nxt_state = PKT_WAIT_HDR;
                                                end
                                        	endcase
                                	end
                                	else
                                        	nxt_state = WAIT_PKT;
				end
				else begin
                                	pkt_src_ip_w = in_tdata_d0[239:208];
                                        pkt_dst_ip_w = in_tdata_d0[207:176];
                                        if (pkt_flags[`PKT_FLG_TCP] || pkt_flags[`PKT_FLG_UDP]) begin
                                        	case(pkt_ip_hdr_len)

                                                4'd5: begin
                                                	pkt_src_port_w = in_tdata_d0[175:160];
                                                        pkt_dst_port_w = in_tdata_d0[159:144];
                                                        if (in_tlast_d0) begin //small pkt//
                                                        	pkt_valid_w = 1'b1;
                                                                nxt_state = WAIT_PKT;
                                                        end
                                                        else
                                                        	nxt_state = PKT_WAIT_HDR;
						end

						default: begin //  TO DO case of IP OPTIONS
                                                	pkt_src_port_w = {PORT_WIDTH{1'b0}};
                                                        pkt_dst_port_w = {PORT_WIDTH{1'b0}};
                                                        if (in_tlast_d0) begin //small pkt//
                                                        	pkt_valid_w = 1'b1;
                                                                nxt_state = WAIT_PKT;
                                                        end
                                                        else
                                                        	nxt_state = PKT_WAIT_HDR;
						end
                                                endcase
					end
                                        else
                                        	nxt_state = WAIT_PKT;
				end
			end
		end

                PKT_WAIT_HDR: begin
                        if (in_valid_d0) begin
                                if (in_tlast_d0) begin //small pkt//
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
                        if(in_valid_d0 && in_tlast_d0)
                                nxt_state = WAIT_PKT;
                end
		endcase
        end

	
	always @(posedge clk or posedge reset) begin
                if (reset) begin
                        cur_state <= WAIT_PKT;

                        pkt_valid <= 1'b0;
                        pkt_ip_hdr_len <= 4'b0;
                        pkt_l4_proto <= {PROTO_WIDTH{1'b0}};
                        pkt_src_ip <= {IP_WIDTH{1'b0}};
                        pkt_dst_ip <= {IP_WIDTH{1'b0}};
                        pkt_src_port <= {PORT_WIDTH{1'b0}};
                        pkt_dst_port <= {PORT_WIDTH{1'b0}};
                        pkt_flags <= {`PKT_FLAGS{1'b0}};
                        pkt_input_if <= {NUM_INPUT_QUEUES{1'b0}};
                        pkt_bytes <= {BYTES_COUNT_WIDTH{1'b0}};
                end
                else begin
                        cur_state <= nxt_state;

                        pkt_valid <= pkt_valid_w;
                        pkt_ip_hdr_len <= pkt_ip_hdr_len_w;
                        pkt_src_ip <= pkt_src_ip_w;
                        pkt_dst_ip <= pkt_dst_ip_w;
                        pkt_src_port <= pkt_src_port_w;
                        pkt_dst_port <= pkt_dst_port_w;
                        pkt_flags <= pkt_flags_w;
                        pkt_input_if <= pkt_input_if_w;
                        pkt_l4_proto <= pkt_l4_proto_w;
                        pkt_bytes <= pkt_bytes_w;
                end
        end


        assign pkt_attributes[(PROTO_WIDTH+PROTO_OFFSET)-1:PROTO_OFFSET]                                        = pkt_l4_proto;
        assign pkt_attributes[(IP_WIDTH+IP_SRC_OFFSET)-1:IP_SRC_OFFSET]                                         = pkt_src_ip;
        assign pkt_attributes[(IP_WIDTH+IP_DST_OFFSET)-1:IP_DST_OFFSET]                                         = pkt_dst_ip;
        assign pkt_attributes[(PORT_WIDTH+PORT_SRC_OFFSET)-1:PORT_SRC_OFFSET]                                   = pkt_src_port;
        assign pkt_attributes[(PORT_WIDTH+PORT_DST_OFFSET)-1:PORT_DST_OFFSET]                                   = pkt_dst_port;
        assign pkt_attributes[(BYTES_COUNT_WIDTH+BYTES_COUNT_OFFSET)-1:BYTES_COUNT_OFFSET]                      = pkt_bytes;
        assign pkt_attributes[(`PKT_FLAGS+PKT_FLAGS_OFFSET)-1:PKT_FLAGS_OFFSET]                                 = pkt_flags;
        assign pkt_attributes[(PRTCL_ID_WIDTH+PRTCL_ID_OFFSET)-1:PRTCL_ID_OFFSET]                               = `PRIORITY_ETH_VLAN_IPv4_TCPnUDP;
        assign pkt_attributes[(NUM_INPUT_QUEUES+NUM_INPUT_QUEUES_OFFSET)-1:NUM_INPUT_QUEUES_OFFSET]             = pkt_input_if;

        endmodule
