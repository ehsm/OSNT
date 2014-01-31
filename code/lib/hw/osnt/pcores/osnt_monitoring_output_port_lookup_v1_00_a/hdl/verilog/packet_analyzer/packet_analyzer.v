/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        packet_analyzer.v
 *
 *  Library:
 *        hw/osnt/pcores/osnt_monitoring_output_port_lookup_v1_00_a
 *
 *  Module:
 *        packet_analyzer
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


`include "defines.vh"

	module packet_analyzer
	#(
    		parameter C_S_AXIS_DATA_WIDTH = 256,
		parameter C_S_AXIS_TUSER_WIDTH = 128,
    		parameter NETWORK_PROTOCOL_COMBINATIONS = 4,
		parameter MAX_HDR_WORDS = 6,
		parameter DIVISION_FACTOR = 2,
		parameter PRTCL_ID_WIDTH = log2(NETWORK_PROTOCOL_COMBINATIONS),
		parameter NUM_INPUT_QUEUES = 8,
		parameter BYTES_COUNT_WIDTH = 16,
		parameter TUPLE_WIDTH = 104,
		parameter ATTRIBUTE_DATA_WIDTH = 135
	)
   	(// --- Interface to the previous stage
    		input  	[C_S_AXIS_DATA_WIDTH-1:0]	tdata,
		input	[C_S_AXIS_TUSER_WIDTH-1:0]	tuser,
		input					valid,
        	input					tlast,
    
    	// --- Results 
		output 					pkt_valid,
    		output	[ATTRIBUTE_DATA_WIDTH-1:0]	pkt_attributes,
	//	{input_port, prtcl_id, pkt_flags, bytes, l4 dst port, l4 src port, dest ip, src ip, proto}

    	// --- Misc
    		input                                   reset,
    		input                                  	clk 
	 );
	

	// Log2 function
        function integer log2;
                input integer number;
                begin
                        log2=0;
                        while(2**log2<number) begin
                                log2=log2+1;
                        end
                end
        endfunction 



 
	//------------------ Internal Parameter ---------------------------
	
	genvar i;
	 
	//---------------------- Wires/Regs -------------------------------
	 		
	wire [C_S_AXIS_DATA_WIDTH-1:0]			pkt_tdata;
	wire [C_S_AXIS_TUSER_WIDTH-1:0]			pkt_tuser;
	wire						pkt_eoh;	
	wire						pkt_tlast;
	wire						pkt_tvalid;
	wire [NETWORK_PROTOCOL_COMBINATIONS-1:0]  	pkt_valid_w;
	wire [(NETWORK_PROTOCOL_COMBINATIONS*ATTRIBUTE_DATA_WIDTH)-1:0]	pkt_attributes_w;

   	generate
   		for (i=0; i<NETWORK_PROTOCOL_COMBINATIONS; i=i+1) begin: DECLARATIONS_W
	 		wire	  			pkt_valid_int;
	 		wire [ATTRIBUTE_DATA_WIDTH-1:0]	pkt_attributes_int;
   		end
 	endgenerate

	//------------------------ Logic ----------------------------------
	
	generate
   		for (i=0; i<NETWORK_PROTOCOL_COMBINATIONS; i=i+1) begin: NETWORK_PROTOCOL_COMBINATIONS_W
   			assign pkt_valid_w[i] = DECLARATIONS_W[i].pkt_valid_int;
   			assign pkt_attributes_w[(i*ATTRIBUTE_DATA_WIDTH)+ATTRIBUTE_DATA_WIDTH-1:(i*ATTRIBUTE_DATA_WIDTH)] = DECLARATIONS_W[i].pkt_attributes_int;
  	 	end
   	endgenerate


	packet_monitor
  	#(
		.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH),
	   	.C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
     	   	.MAX_HDR_WORDS (MAX_HDR_WORDS)
  	) packet_monitor_inst (
	// --- Interface to the previous stage
	 	.tdata  	(tdata),
	 	.valid 		(valid),
    		.tlast 		(tlast),
		.tuser		(tuser),

    	// --- Results 
    		.out_tdata	(pkt_tdata),
		.out_tuser	(pkt_tuser),
    		.out_valid	(pkt_tvalid),
    		.out_eoh 	(pkt_eoh),
    		.out_tlast	(pkt_tlast),

    		.sample_results (),
    
    	// --- Misc
    		.reset 		(reset),
    		.clk 		(clk)
	);
	 
	 // Protocol Combinations
	`include "network_protocol_combinations.inc"
	
	`ifdef PRIORITY_WHEN_NO_HIT
	 WHEN_NO_HIT 
         #(
		.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
                .C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
                .TUPLE_WIDTH(TUPLE_WIDTH),
                .NUM_INPUT_QUEUES(NUM_INPUT_QUEUES),
                .PRTCL_ID_WIDTH(PRTCL_ID_WIDTH),
                .BYTES_COUNT_WIDTH(BYTES_COUNT_WIDTH),
		.ATTRIBUTE_DATA_WIDTH(ATTRIBUTE_DATA_WIDTH)
         ) WHEN_NO_HIT_inst
	 (
	 // --- Interface to the previous stage
    		.in_tdata 	(pkt_tdata),
    		.in_valid 	(pkt_tvalid),
    		.in_tlast 	(pkt_tlast),
    		.in_eoh 	(pkt_eoh),
		.in_tuser	(pkt_tuser),
 
    		.pkt_valid 	(DECLARATIONS_W[`PRIORITY_WHEN_NO_HIT].pkt_valid_int),
    		.pkt_attributes (DECLARATIONS_W[`PRIORITY_WHEN_NO_HIT].pkt_attributes_int),

    	// --- Misc
    		.reset 		(reset),
    		.clk 		(clk)
	 );
	`endif
	
	 
	 // --- Multistage Muxing Logic
	 multistage_priority_mux
	 #(
		.DIVISION_FACTOR(DIVISION_FACTOR),
	 	.DATA_GROUPS	(NETWORK_PROTOCOL_COMBINATIONS),
		.ATTRIBUTE_DATA_WIDTH(ATTRIBUTE_DATA_WIDTH) 
	 ) multistage_priority_mux_inst (
	 // --- Results
    		.valid_o 	(pkt_valid),
    		.data_o		(pkt_attributes),

    		.data_groups_i	(pkt_attributes_w),
   		.valid_groups_i (pkt_valid_w),

    	// --- Misc
    		.reset 		(reset),
    		.clk 		(clk)
	 );

	 endmodule
