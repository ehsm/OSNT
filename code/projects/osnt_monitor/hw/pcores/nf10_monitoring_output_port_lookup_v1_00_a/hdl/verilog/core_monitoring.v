/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        core_monitoring.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_monitoring_output_port_lookup_v1_10_a
 *
 *  Module:
 *        core_monitoring
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


	module core_monitoring
	#(
    	//Master AXI Stream Data Width
    		parameter C_M_AXIS_DATA_WIDTH=256,
    		parameter C_S_AXIS_DATA_WIDTH=256,
    		parameter C_M_AXIS_TUSER_WIDTH=128,
    		parameter C_S_AXIS_TUSER_WIDTH=128,
		parameter C_S_AXI_DATA_WIDTH = 32,
    		parameter SRC_PORT_POS=16,
    		parameter DST_PORT_POS=24,
    		parameter NUM_QUEUES=8,
    		parameter MON_LUT_DEPTH_BITS=4,
    		parameter TUPLE_WIDTH = 104,
                parameter NETWORK_PROTOCOL_COMBINATIONS = 4,
                parameter MAX_HDR_WORDS = 6,
                parameter DIVISION_FACTOR = 2,
                parameter BYTES_COUNT_WIDTH = 16,
		parameter TIMESTAMP_WIDTH = 64,
                parameter ATTRIBUTE_DATA_WIDTH = 135
	)
	(
    	// Global Ports
    		input axi_aclk,
    		input axi_resetn,

    	// Master Stream Ports (interface to data path)
    		output reg [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
    		output reg [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tstrb,
    		output reg [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
    		output reg m_axis_tvalid,
    		input  m_axis_tready,
    		output reg m_axis_tlast,

    	// Slave Stream Ports (interface to RX queues)
    		input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
    		input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tstrb,
    		input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    		input  s_axis_tvalid,
    		output s_axis_tready,
    		input  s_axis_tlast,

    	// TCAM
    		input [MON_LUT_DEPTH_BITS-1:0] mon_rd_addr,
    		input mon_rd_req,
    		output [TUPLE_WIDTH-1:0] mon_rd_rule,
    		output [TUPLE_WIDTH-1:0] mon_rd_rulemask,
    		output mon_rd_ack,

    		input [MON_LUT_DEPTH_BITS-1:0] mon_wr_addr,
    		input mon_wr_req,
    		input [TUPLE_WIDTH-1:0] mon_wr_rule,
    		input [TUPLE_WIDTH-1:0] mon_wr_rulemask,
    		output mon_wr_ack,

    	// stats handler
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
		input [TIMESTAMP_WIDTH-1:0]	stamp_counter,

	// stats misc
		input				stats_freeze,
		input				rst_stats
	);


	//--------------------- Internal Parameter-------------------------

   	localparam NUM_STATES               = 2;
   	localparam WAIT_TILL_DONE_DECODE    = 1;
   	localparam IN_PACKET                = 2;

   	localparam METADATA_TUSER	    = 32;
       
	//---------------------- Wires and regs---------------------------

	wire [ATTRIBUTE_DATA_WIDTH-1:0]		pkt_attributes;
	wire					pkt_valid;
        wire [ATTRIBUTE_DATA_WIDTH-1:0]         pkt_attributes_w;
        wire                                    pkt_valid_w;
        reg [ATTRIBUTE_DATA_WIDTH-1:0]          pkt_attributes_reg;
        reg                                     pkt_valid_reg;
  
   	wire                         		lookup_done;

   	reg                          		in_fifo_rd_en;
   	wire                         		in_fifo_nearly_full;
   	wire                         		in_fifo_empty;

   	wire [NUM_QUEUES-1:0]        		dst_ports;
   	wire [NUM_QUEUES-1:0]			fifo_dst_ports;
 
   	wire					hit_fifo_empty;
   	reg					hit_fifo_rd_en;

   	wire [C_S_AXIS_TUSER_WIDTH-1:0] 	tuser_fifo;
   	wire [((C_M_AXIS_DATA_WIDTH/8))-1:0] 	tstrb_fifo;
   	wire 					tlast_fifo;
   	wire [C_M_AXIS_DATA_WIDTH-1:0]        	tdata_fifo;

   	wire [TUPLE_WIDTH-1:0]       		mon_rd_rulemask_inverted;

   	reg [NUM_STATES-1:0]			state,state_next;

   	reg [C_M_AXIS_DATA_WIDTH-1:0]      	m_axis_tdata_next;
   	reg [((C_M_AXIS_DATA_WIDTH/8))-1:0]	m_axis_tstrb_next;
   	reg [C_M_AXIS_TUSER_WIDTH-1:0] 		m_axis_tuser_next;
   	reg 					m_axis_tvalid_next;
   	reg 					m_axis_tlast_next;

   //------------------------- Modules-------------------------------

  	assign mon_rd_rulemask = ~mon_rd_rulemask_inverted;
  	assign s_axis_tready = !in_fifo_nearly_full;
        assign pkt_valid_w = pkt_valid_reg;
        assign pkt_attributes_w = pkt_attributes_reg;

	packet_analyzer
     	#(
                .C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
		.C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
                .NETWORK_PROTOCOL_COMBINATIONS(NETWORK_PROTOCOL_COMBINATIONS),
                .MAX_HDR_WORDS(MAX_HDR_WORDS),
                .DIVISION_FACTOR(DIVISION_FACTOR),
                .NUM_INPUT_QUEUES(NUM_QUEUES),
                .BYTES_COUNT_WIDTH(BYTES_COUNT_WIDTH),
                .TUPLE_WIDTH(TUPLE_WIDTH),
                .ATTRIBUTE_DATA_WIDTH(ATTRIBUTE_DATA_WIDTH)
	) packet_analyzer
        (
	// --- input
               	.tdata(s_axis_tdata),
                .tuser(s_axis_tuser),
                .valid(s_axis_tvalid & ~in_fifo_nearly_full),
                .tlast(s_axis_tlast),

        // --- output 
        	.pkt_valid(pkt_valid),
        	.pkt_attributes(pkt_attributes),
        
	// --- misc
        	.reset(~axi_resetn),
        	.clk(axi_aclk));


        stats_handler
        #(
		.C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
                .TIMESTAMP_WIDTH(TIMESTAMP_WIDTH),
                .ATTRIBUTE_DATA_WIDTH(ATTRIBUTE_DATA_WIDTH),
                .NUM_INPUT_QUEUES(NUM_QUEUES),
                .TUPLE_WIDTH(TUPLE_WIDTH),
                .BYTES_COUNT_WIDTH(BYTES_COUNT_WIDTH)
        ) stats_handler
        (
        // --- input
                .pkt_attributes(pkt_attributes_w),
                .pkt_valid(pkt_valid_w),
                
		.stamp_counter(stamp_counter),
                
		.stats_freeze(stats_freeze),
                .rst_stats(rst_stats),

        // --- output
                .pkt_cnt_0(pkt_cnt_0),
                .pkt_cnt_1(pkt_cnt_1),
                .pkt_cnt_2(pkt_cnt_2),
                .pkt_cnt_3(pkt_cnt_3),

                .bytes_cnt_0(bytes_cnt_0),
                .bytes_cnt_1(bytes_cnt_1),
                .bytes_cnt_2(bytes_cnt_2),
                .bytes_cnt_3(bytes_cnt_3),

                .vlan_cnt_0(vlan_cnt_0),
                .vlan_cnt_1(vlan_cnt_1),
                .vlan_cnt_2(vlan_cnt_2),
                .vlan_cnt_3(vlan_cnt_3),

                .ip_cnt_0(ip_cnt_0),
                .ip_cnt_1(ip_cnt_1),
                .ip_cnt_2(ip_cnt_2),
                .ip_cnt_3(ip_cnt_3),

                .udp_cnt_0(udp_cnt_0),
                .udp_cnt_1(udp_cnt_1),
                .udp_cnt_2(udp_cnt_2),
                .udp_cnt_3(udp_cnt_3),

                .tcp_cnt_0(tcp_cnt_0),
                .tcp_cnt_1(tcp_cnt_1),
                .tcp_cnt_2(tcp_cnt_2),
                .tcp_cnt_3(tcp_cnt_3),

                .stats_time_high(stats_time_high),
                .stats_time_low(stats_time_low),

        // --- misc
                .reset(~axi_resetn),
                .clk(axi_aclk));

	
	process_pkt
     	#(
		.TUPLE_WIDTH (TUPLE_WIDTH),
       		.NUM_QUEUES (NUM_QUEUES),
       		.MON_LUT_DEPTH_BITS(MON_LUT_DEPTH_BITS)
	)
     	process_pkt
        (
	// --- input
		.tuple(pkt_attributes_w[TUPLE_WIDTH-1:0]),
          	.src_port(pkt_attributes_w[ATTRIBUTE_DATA_WIDTH-1:ATTRIBUTE_DATA_WIDTH-NUM_QUEUES]),
          	.lookup_req (pkt_valid_w),

	// --- output
          	.dst_ports (dst_ports),
          	.lookup_done (lookup_done),

	// --- TCAM management
          	.rule_rd_addr(mon_rd_addr),
          	.rule_rd_req(mon_rd_req),
          	.rule_rd(mon_rd_rule),
          	.rule_rd_mask(mon_rd_rulemask_inverted),
          	.rule_rd_ack(mon_rd_ack),
          	.rule_wr_addr(mon_wr_addr),
          	.rule_wr_req(mon_wr_req),
          	.rule_wr(mon_wr_rule),
          	.rule_wr_mask(~mon_wr_rulemask),
          	.rule_wr_ack(mon_wr_ack),

	// --- misc
          	.reset(~axi_resetn),
          	.clk(axi_aclk));


   	/* The size of this fifo has to be large enough to fit the previous modules' headers
	* and the ethernet header */

   	fallthrough_small_fifo
	#(
		.WIDTH(C_M_AXIS_DATA_WIDTH+C_M_AXIS_TUSER_WIDTH+C_M_AXIS_DATA_WIDTH/8+1),
		.MAX_DEPTH_BITS(3)
	)
      	pkt_fifo
        (	.din ({s_axis_tlast, s_axis_tuser, s_axis_tstrb, s_axis_tdata}),     // Data in
         	.wr_en (s_axis_tvalid & ~in_fifo_nearly_full),               // Write enable
         	.rd_en (in_fifo_rd_en),       // Read the next word
         	.dout ({tlast_fifo, tuser_fifo, tstrb_fifo, tdata_fifo}),
         	.full (),
         	.prog_full (),
         	.nearly_full (in_fifo_nearly_full),
         	.empty (in_fifo_empty),
         	.reset (~axi_resetn),
         	.clk (axi_aclk));


	fallthrough_small_fifo
	#(
		.WIDTH(NUM_QUEUES),
		.MAX_DEPTH_BITS(2))
      	hit_fifo
        (
		.din (dst_ports),     // Data in
         	.wr_en (lookup_done),               // Write enable
         	.rd_en (hit_fifo_rd_en),       // Read the next word
         	.dout (fifo_dst_ports),
         	.full (),
         	.prog_full (),
         	.nearly_full (),
         	.empty (hit_fifo_empty),
         	.reset (~axi_resetn),
         	.clk (axi_aclk));


   /*********************************************************************
    * Wait until the TUPLE has been searched in TCAM, then write the 
    * module header and move the packet to the right output queue/s
    **********************************************************************/

	always @(*) begin
      		m_axis_tuser_next = tuser_fifo;
      		m_axis_tstrb_next = tstrb_fifo;
      		m_axis_tlast_next = tlast_fifo;
      		m_axis_tdata_next = tdata_fifo;
      		m_axis_tvalid_next = 0;
   
      		in_fifo_rd_en = 0;
      		hit_fifo_rd_en = 0;
      
      		state_next = state;

      		case(state)
        
		WAIT_TILL_DONE_DECODE: begin
        		if(!hit_fifo_empty) begin
				m_axis_tvalid_next = 1;
				m_axis_tuser_next[DST_PORT_POS+7:DST_PORT_POS] = fifo_dst_ports;
				if(m_axis_tready) begin
					in_fifo_rd_en = 1;
					hit_fifo_rd_en = 1;
					state_next = IN_PACKET;
				end
			end
		end


        	IN_PACKET: begin
			if(!in_fifo_empty) begin
				m_axis_tvalid_next = 1;
				if(m_axis_tready) begin
					in_fifo_rd_en = 1;
					if(tlast_fifo)
                                        	state_next = WAIT_TILL_DONE_DECODE;
				end
			end
		end

		endcase // case(state)
	end // always @ (*)


	always @(posedge axi_aclk) begin
      		if(~axi_resetn) begin
         		state 		<= WAIT_TILL_DONE_DECODE;
         		m_axis_tvalid   <= 0;
         		m_axis_tdata    <= 0;
         		m_axis_tuser    <= 0;
         		m_axis_tstrb    <= 0;
         		m_axis_tlast    <= 0;
			pkt_valid_reg   <= 0;
			pkt_attributes_reg  <= 0;
      		end
      		else begin
         		state <= state_next;

	 		m_axis_tvalid<= m_axis_tvalid_next;
         		m_axis_tdata <= m_axis_tdata_next;
         		m_axis_tuser <= m_axis_tuser_next;
         		m_axis_tstrb <= m_axis_tstrb_next;
         		m_axis_tlast <= m_axis_tlast_next;

			pkt_valid_reg<= pkt_valid;
			pkt_attributes_reg<=pkt_attributes;
      		end
   	end
	endmodule // output_port_lookup

