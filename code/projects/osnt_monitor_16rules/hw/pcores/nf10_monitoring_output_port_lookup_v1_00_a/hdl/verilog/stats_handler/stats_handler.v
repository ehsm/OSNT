/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        stats_handler.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_monitoring_output_port_lookup_v1_10_a
 *
 *  Module:
 *        stats_handler
 *
 *  Author:
 *        Gianni Antichi
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

	module stats_handler
	#(
		parameter C_S_AXI_DATA_WIDTH = 32,
    		parameter TIMESTAMP_WIDTH =64,
		parameter ATTRIBUTE_DATA_WIDTH = 135,
		parameter NUM_INPUT_QUEUES =8,
		parameter TUPLE_WIDTH = 104,
		parameter BYTES_COUNT_WIDTH = 16
	)
	(
    	// Global Ports
    		input clk,
    		input reset,

	// packet attributes
		input [ATTRIBUTE_DATA_WIDTH-1:0] pkt_attributes,
		input	pkt_valid,

	// statistics	
                output [C_S_AXI_DATA_WIDTH-1:0] pkt_cnt_0,
                output [C_S_AXI_DATA_WIDTH-1:0] pkt_cnt_1,
                output [C_S_AXI_DATA_WIDTH-1:0] pkt_cnt_2,
                output [C_S_AXI_DATA_WIDTH-1:0] pkt_cnt_3,

                output [C_S_AXI_DATA_WIDTH-1:0] bytes_cnt_0,
                output [C_S_AXI_DATA_WIDTH-1:0] bytes_cnt_1,
                output [C_S_AXI_DATA_WIDTH-1:0] bytes_cnt_2,
                output [C_S_AXI_DATA_WIDTH-1:0] bytes_cnt_3,

                output [C_S_AXI_DATA_WIDTH-1:0] vlan_cnt_0,
                output [C_S_AXI_DATA_WIDTH-1:0] vlan_cnt_1,
                output [C_S_AXI_DATA_WIDTH-1:0] vlan_cnt_2,
                output [C_S_AXI_DATA_WIDTH-1:0] vlan_cnt_3,

                output [C_S_AXI_DATA_WIDTH-1:0] ip_cnt_0,
                output [C_S_AXI_DATA_WIDTH-1:0] ip_cnt_1,
                output [C_S_AXI_DATA_WIDTH-1:0] ip_cnt_2,
                output [C_S_AXI_DATA_WIDTH-1:0] ip_cnt_3,

                output [C_S_AXI_DATA_WIDTH-1:0] udp_cnt_0,
                output [C_S_AXI_DATA_WIDTH-1:0] udp_cnt_1,
                output [C_S_AXI_DATA_WIDTH-1:0] udp_cnt_2,
                output [C_S_AXI_DATA_WIDTH-1:0] udp_cnt_3,

                output [C_S_AXI_DATA_WIDTH-1:0] tcp_cnt_0,
                output [C_S_AXI_DATA_WIDTH-1:0] tcp_cnt_1,
                output [C_S_AXI_DATA_WIDTH-1:0] tcp_cnt_2,
                output [C_S_AXI_DATA_WIDTH-1:0] tcp_cnt_3,

                output [C_S_AXI_DATA_WIDTH-1:0] stats_time_high,
                output [C_S_AXI_DATA_WIDTH-1:0] stats_time_low,
 
	// stamp counter
                input [TIMESTAMP_WIDTH-1:0]     stamp_counter,

	// misc stats
                input                           stats_freeze,
                input                           rst_stats
	);

	//--------------------- Internal Parameter-------------------------

	localparam PHY0 = 8'b0000_0001;
	localparam PHY1 = 8'b0000_0100;
	localparam PHY2 = 8'b0001_0000;
	localparam PHY3 = 8'b0100_0000;

	localparam NUM_PHY = 4;

	localparam FLAG_IP = TUPLE_WIDTH+BYTES_COUNT_WIDTH;
	localparam FLAG_TCP = FLAG_IP + 1;
	localparam FLAG_UDP = FLAG_IP + 2;
	localparam FLAG_VLAN_Q = FLAG_IP + 3;
	localparam FLAG_VLAN_AD = FLAG_IP + 4;  

  	//---------------------- Wires and regs---------------------------

	reg [C_S_AXI_DATA_WIDTH-1:0] pkt_cnt [NUM_PHY-1:0];
        reg [C_S_AXI_DATA_WIDTH-1:0] bytes_cnt [NUM_PHY-1:0];
        reg [C_S_AXI_DATA_WIDTH-1:0] vlan_cnt [NUM_PHY-1:0];
        reg [C_S_AXI_DATA_WIDTH-1:0] ip_cnt [NUM_PHY-1:0];
        reg [C_S_AXI_DATA_WIDTH-1:0] tcp_cnt [NUM_PHY-1:0];
        reg [C_S_AXI_DATA_WIDTH-1:0] udp_cnt [NUM_PHY-1:0];

        reg [C_S_AXI_DATA_WIDTH-1:0] pkt_cnt_tmp [NUM_PHY-1:0];
        reg [C_S_AXI_DATA_WIDTH-1:0] bytes_cnt_tmp [NUM_PHY-1:0];
        reg [C_S_AXI_DATA_WIDTH-1:0] vlan_cnt_tmp [NUM_PHY-1:0];
        reg [C_S_AXI_DATA_WIDTH-1:0] ip_cnt_tmp [NUM_PHY-1:0];
        reg [C_S_AXI_DATA_WIDTH-1:0] tcp_cnt_tmp [NUM_PHY-1:0];
        reg [C_S_AXI_DATA_WIDTH-1:0] udp_cnt_tmp [NUM_PHY-1:0];

	reg [C_S_AXI_DATA_WIDTH-1:0] time_high_tmp;
        reg [C_S_AXI_DATA_WIDTH-1:0] time_low_tmp;
 
        reg [C_S_AXI_DATA_WIDTH-1:0] pkt_cnt_tmp_next [NUM_PHY-1:0];
        reg [C_S_AXI_DATA_WIDTH-1:0] bytes_cnt_tmp_next [NUM_PHY-1:0];
        reg [C_S_AXI_DATA_WIDTH-1:0] vlan_cnt_tmp_next [NUM_PHY-1:0];
        reg [C_S_AXI_DATA_WIDTH-1:0] ip_cnt_tmp_next [NUM_PHY-1:0];
        reg [C_S_AXI_DATA_WIDTH-1:0] tcp_cnt_tmp_next [NUM_PHY-1:0];
        reg [C_S_AXI_DATA_WIDTH-1:0] udp_cnt_tmp_next [NUM_PHY-1:0];

        reg [C_S_AXI_DATA_WIDTH-1:0] time_high_tmp_next;
        reg [C_S_AXI_DATA_WIDTH-1:0] time_low_tmp_next;


	wire [NUM_INPUT_QUEUES-1:0]  pkt_src;
	wire [BYTES_COUNT_WIDTH-1:0] bytes;
	wire	                     is_ip;
	wire			     is_vlan;
	wire			     is_udp;
	wire			     is_tcp;

	reg [NUM_PHY-1:0] 	     valid_phy;

	integer	i;

        //---------------------- Logic ---------------------------


  	always @ (*) begin
        	valid_phy = 2'd0;
        	if(pkt_valid) begin
                	case(pkt_src)
                        	8'b00000001: valid_phy = 'h1;
                        	8'b00000100: valid_phy = 'h2;
                        	8'b00010000: valid_phy = 'h4;
                        	8'b01000000: valid_phy = 'h8;
                        	default    : valid_phy = 'h0;
                	endcase
        	end
   	end

	assign pkt_src = pkt_attributes[ATTRIBUTE_DATA_WIDTH-1:ATTRIBUTE_DATA_WIDTH-NUM_INPUT_QUEUES];
	assign bytes   = pkt_attributes[TUPLE_WIDTH+BYTES_COUNT_WIDTH-1:TUPLE_WIDTH];
	assign is_ip   = (pkt_attributes[FLAG_IP]);
	assign is_tcp  = (pkt_attributes[FLAG_TCP]);
	assign is_udp  = (pkt_attributes[FLAG_UDP]);
	assign is_vlan = (pkt_attributes[FLAG_VLAN_Q] | pkt_attributes[FLAG_VLAN_AD]);



	generate
	genvar k;
	for(k=0;k<NUM_PHY;k=k+1) begin: statistics_freeze
		always@(pkt_cnt[k],bytes_cnt[k],vlan_cnt[k],ip_cnt[k],tcp_cnt[k],udp_cnt[k],stats_freeze,pkt_cnt_tmp[k],bytes_cnt_tmp[k],vlan_cnt_tmp[k],ip_cnt_tmp[k],tcp_cnt_tmp[k],udp_cnt_tmp[k])begin
	//	always@(*)begin
			if(!stats_freeze) begin
				pkt_cnt_tmp_next[k] = pkt_cnt[k];
                        	bytes_cnt_tmp_next[k] = bytes_cnt[k];
                        	vlan_cnt_tmp_next[k] = vlan_cnt[k];
                        	ip_cnt_tmp_next[k] = ip_cnt[k];
                        	tcp_cnt_tmp_next[k] = tcp_cnt[k];
                        	udp_cnt_tmp_next[k] = udp_cnt[k];
			end
			else begin
                                pkt_cnt_tmp_next[k] = pkt_cnt_tmp[k];
                                bytes_cnt_tmp_next[k] = bytes_cnt_tmp[k];
                                vlan_cnt_tmp_next[k] = vlan_cnt_tmp[k];
                                ip_cnt_tmp_next[k] = ip_cnt_tmp[k];
                                tcp_cnt_tmp_next[k] = tcp_cnt_tmp[k];
                                udp_cnt_tmp_next[k] = udp_cnt_tmp[k];
                        end			
		 end
	end
	endgenerate

	always@(*) begin
		if(!stats_freeze) begin
			time_high_tmp_next = stamp_counter[TIMESTAMP_WIDTH-1:32];
                        time_low_tmp_next = stamp_counter[31:0];
		end
		else begin
			time_high_tmp_next = time_high_tmp;
                        time_low_tmp_next = time_low_tmp;
		end
	end

  	always @ (posedge clk) begin
    		if (reset) begin
			for(i=0;i<NUM_PHY;i=i+1) begin
				pkt_cnt[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                                bytes_cnt[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                                vlan_cnt[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                                ip_cnt[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                                tcp_cnt[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                                udp_cnt[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};

                                pkt_cnt_tmp[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                                bytes_cnt_tmp[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                                vlan_cnt_tmp[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                                ip_cnt_tmp[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                                tcp_cnt_tmp[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                                udp_cnt_tmp[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
			end

			time_high_tmp <= {C_S_AXI_DATA_WIDTH{1'b0}};
                        time_low_tmp <= {C_S_AXI_DATA_WIDTH{1'b0}};
		end
    		else if (rst_stats) begin    
			for(i=0;i<NUM_PHY;i=i+1) begin
                                pkt_cnt[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                                bytes_cnt[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                                vlan_cnt[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                                ip_cnt[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                                tcp_cnt[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                                udp_cnt[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
                        end
		end
    		else begin
			for(i=0;i<NUM_PHY;i=i+1) begin
				if(valid_phy[i]) begin
                                	pkt_cnt[i] <= pkt_cnt[i]+1;
                                	bytes_cnt[i] <= bytes_cnt[i]+bytes;
                                	vlan_cnt[i] <= vlan_cnt[i]+is_vlan;
                                	ip_cnt[i] <= ip_cnt[i]+is_ip;
                                	tcp_cnt[i] <= tcp_cnt[i]+is_tcp;
                                	udp_cnt[i] <= udp_cnt[i]+is_udp;
				end
                                pkt_cnt_tmp[i] <= pkt_cnt_tmp_next[i];
                                bytes_cnt_tmp[i] <= bytes_cnt_tmp_next[i];
                                vlan_cnt_tmp[i] <= vlan_cnt_tmp_next[i];
                                ip_cnt_tmp[i] <= ip_cnt_tmp_next[i];
                                tcp_cnt_tmp[i] <= tcp_cnt_tmp_next[i];
                                udp_cnt_tmp[i] <= udp_cnt_tmp_next[i];
			end
			time_high_tmp <= time_high_tmp_next;
			time_low_tmp <= time_low_tmp_next;
		end
	end


	// demultiplex the statistics
	assign pkt_cnt_0 = pkt_cnt_tmp[0];
        assign pkt_cnt_1 = pkt_cnt_tmp[1];
        assign pkt_cnt_2 = pkt_cnt_tmp[2];
        assign pkt_cnt_3 = pkt_cnt_tmp[3];			
	
        assign bytes_cnt_0 = bytes_cnt_tmp[0];
        assign bytes_cnt_1 = bytes_cnt_tmp[1];
        assign bytes_cnt_2 = bytes_cnt_tmp[2];
        assign bytes_cnt_3 = bytes_cnt_tmp[3];

        assign vlan_cnt_0 = vlan_cnt_tmp[0];
        assign vlan_cnt_1 = vlan_cnt_tmp[1];
        assign vlan_cnt_2 = vlan_cnt_tmp[2];
        assign vlan_cnt_3 = vlan_cnt_tmp[3];

        assign ip_cnt_0 = ip_cnt_tmp[0];
        assign ip_cnt_1 = ip_cnt_tmp[1];
        assign ip_cnt_2 = ip_cnt_tmp[2];
        assign ip_cnt_3 = ip_cnt_tmp[3];

        assign tcp_cnt_0 = tcp_cnt_tmp[0];
        assign tcp_cnt_1 = tcp_cnt_tmp[1];
        assign tcp_cnt_2 = tcp_cnt_tmp[2];
        assign tcp_cnt_3 = tcp_cnt_tmp[3];

        assign udp_cnt_0 = udp_cnt_tmp[0];
        assign udp_cnt_1 = udp_cnt_tmp[1];
        assign udp_cnt_2 = udp_cnt_tmp[2];
        assign udp_cnt_3 = udp_cnt_tmp[3];

	assign stats_time_high = time_high_tmp;
        assign stats_time_low = time_low_tmp;
 
endmodule // stats_handler

