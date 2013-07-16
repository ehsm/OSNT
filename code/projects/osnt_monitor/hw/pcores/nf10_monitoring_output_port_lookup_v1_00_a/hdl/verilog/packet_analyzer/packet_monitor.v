//***************************************************************************//
//                  (C) COPYRIGHT 2003-2007 CARE Pvt Ltd.                      
//                         ALL RIGHTS RESERVED                                 
//                                                                             
// 	Entire notice above must be reproduced on all authorized copies.       
//                                                                            
// Project                    : Protocol and Data Search Engine                
// Module                     :	Header Parser
// Designer                   : CARE/NY                                       
// Date of creation           : 26-09-07                                       
// Date of last modifaction   :                                                
//                                                                             
// Description                :
//                                                                             
// Revision                   :	1.0                                            
//                                                                             
// Revision History                                                            
//                                                                             
// Date       Version       Designer      Change         Description           
//                                                                             
//                                                                            
//***************************************************************************//
////////////////////////////  Includes & Defines //////////////////////////////

`include "defines.vh"

	module packet_monitor
	#(
  		parameter C_S_AXIS_DATA_WIDTH  = 256,
		parameter C_S_AXIS_TUSER_WIDTH = 128,
  		parameter MAX_HDR_WORDS        = 6
	)
	(
	// --- Interface to the previous stage
    		input	[C_S_AXIS_DATA_WIDTH-1:0]	tdata,
		input	[C_S_AXIS_TUSER_WIDTH-1:0]	tuser,
   		input					valid,
    		input					tlast,

    	// --- Results
    		output reg [C_S_AXIS_DATA_WIDTH-1:0]	out_tdata,
		output reg [C_S_AXIS_TUSER_WIDTH-1:0]	out_tuser,
    		output reg				out_valid,
    		output reg				out_eoh, // asserted when MAX_HDR_WRDS (data) is receved
    		output reg				out_tlast,
    		output reg				sample_results,

    	// --- Misc
    		input					reset,
    		input                                 	clk 
	);
	 
	//------------------ Internal Parameter ---------------------------
	 
	localparam IDLE		= 2'd0,
		   PKT_WAIT_HDR = 2'd1,
	 	   PKT_WAIT_EOP = 2'd2;
	 
	//---------------------- Wires/Regs -------------------------------
	 
	reg [C_S_AXIS_DATA_WIDTH-1:0]	in_data_d0;
	reg [C_S_AXIS_TUSER_WIDTH-1:0]	in_tuser_d0;
	reg				in_wr_d0;
	reg				in_eop_d0;
	                      		
	reg [1:0]			sample_results_dly;
	                      		
	reg				out_eoh_w;
	 
	reg [MAX_HDR_WORDS-1:0] 	pkt_vlaid_delay;
	 
	reg [1:0] 			cur_state;
	reg [1:0]			nxt_state;
	 
	//------------------------ Logic ----------------------------------
	 
	always @(posedge clk or posedge reset) begin
		if(reset) begin
	 		in_wr_d0 <= 1'b0;
	 		in_eop_d0 <= 1'b0;
	 	end
	 	else begin
	 		in_wr_d0 <= valid;
	 		in_eop_d0 <= tlast;
	 	end
	 end	 
	 
	always @(posedge clk) begin
	 	in_data_d0  <= tdata;
		in_tuser_d0 <= tuser;
	end	 
	
	 
	always @(*) begin
		nxt_state = cur_state;
		out_eoh_w = 1'b0;

		case (cur_state)

		IDLE: begin
	 		if (in_wr_d0)
	 			nxt_state = PKT_WAIT_HDR;
		end
	 		
	 	PKT_WAIT_HDR: begin
	 		if (in_wr_d0) begin
		 		if (in_eop_d0) begin /*small pkt*/
		 			out_eoh_w = 1'b1;
		 			nxt_state = IDLE;
		 		end
		 		else if (pkt_vlaid_delay[MAX_HDR_WORDS-1]) begin // if valid when in_eop is 1 then will be discarded in the protocol parser blocks
						out_eoh_w = 1'b1;
		 				nxt_state = PKT_WAIT_EOP;
		 		end
		 	end
	 	end
	 		
	 	PKT_WAIT_EOP: begin
			if (in_wr_d0 && in_eop_d0) begin
	 			nxt_state = IDLE;
	 		end
	 	end
	 		
	 	endcase
	end
	 
	 
	always @(posedge clk or posedge reset) begin
		if (reset)
	 		sample_results_dly <= 2'b0;
		else if (out_eoh_w && (cur_state == PKT_WAIT_HDR))
	 		sample_results_dly <= {1'b0, 1'b1};
		else
	 		sample_results_dly <= {sample_results_dly[0], 1'b0};
	end
	 
	 
	always @(posedge clk or posedge reset) begin
		if (reset)
			pkt_vlaid_delay <= 0;
		else if (cur_state == IDLE)
			pkt_vlaid_delay <= 0;
		else if (in_wr_d0)
			pkt_vlaid_delay <= {pkt_vlaid_delay[MAX_HDR_WORDS-2:0], (cur_state == PKT_WAIT_HDR)};
	end
	 
	 
	always @(posedge clk or posedge reset) begin
		if (reset) begin
	 		cur_state <= IDLE;

	 		out_tdata <= {C_S_AXIS_DATA_WIDTH{1'b0}};
	 		out_tuser <= {C_S_AXIS_TUSER_WIDTH{1'b0}};
	 		out_valid <= 1'b0;
	 		out_eoh <= 1'b0;
	 		out_tlast <= 1'b0;

	 		sample_results <= 1'b0;
		end
	 	else begin	 		
	 		cur_state <= nxt_state;

	 		out_tdata <= in_data_d0;
			out_tuser <= in_tuser_d0;
	 		out_valid <= in_wr_d0;
	 		out_eoh   <= out_eoh_w;
	 		out_tlast <= in_eop_d0;

	 		sample_results <= sample_results_dly[1];
		end
	end
 
	endmodule
