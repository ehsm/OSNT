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

        reg                             pkt_valid_w;
        reg [NUM_INPUT_QUEUES-1:0]      pkt_input_if_w;
        reg [BYTES_COUNT_WIDTH-1:0]     pkt_bytes_w;

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
		pkt_input_if_w = pkt_input_if;
                pkt_bytes_w = pkt_bytes;

		case (cur_state)		 		
	 	

		WAIT_PKT: begin
			pkt_input_if_w = {NUM_INPUT_QUEUES{1'b0}};
			pkt_bytes_w = {BYTES_COUNT_WIDTH{1'b0}};
			
			if(in_valid_d0) begin
				pkt_input_if_w = in_tuser_d0[SRC_PORT_POS+NUM_INPUT_QUEUES-1:SRC_PORT_POS];
				pkt_bytes_w = in_tuser_d0[15:0];
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
	 	end
	 	else begin
	 		cur_state <= nxt_state;
	 		
	 		pkt_valid <= pkt_valid_w;	 	
			pkt_input_if <= pkt_input_if_w;
                        pkt_bytes <= pkt_bytes_w;
		end
	end           
	

        assign pkt_attributes[(PROTO_WIDTH+PROTO_OFFSET)-1:PROTO_OFFSET]                                        = {PROTO_WIDTH{1'b0}};
        assign pkt_attributes[(IP_WIDTH+IP_SRC_OFFSET)-1:IP_SRC_OFFSET]                                         = {IP_WIDTH{1'b0}};
        assign pkt_attributes[(IP_WIDTH+IP_DST_OFFSET)-1:IP_DST_OFFSET]                                         = {IP_WIDTH{1'b0}};
        assign pkt_attributes[(PORT_WIDTH+PORT_SRC_OFFSET)-1:PORT_SRC_OFFSET]                                   = {PORT_WIDTH{1'b0}};
        assign pkt_attributes[(PORT_WIDTH+PORT_DST_OFFSET)-1:PORT_DST_OFFSET]                                   = {PORT_WIDTH{1'b0}};
        assign pkt_attributes[(BYTES_COUNT_WIDTH+BYTES_COUNT_OFFSET)-1:BYTES_COUNT_OFFSET]                      = pkt_bytes;
        assign pkt_attributes[(`PKT_FLAGS+PKT_FLAGS_OFFSET)-1:PKT_FLAGS_OFFSET]                                 = {`PKT_FLAGS{1'b0}};
        assign pkt_attributes[(PRTCL_ID_WIDTH+PRTCL_ID_OFFSET)-1:PRTCL_ID_OFFSET]                               = `PRIORITY_WHEN_NO_HIT;
        assign pkt_attributes[(NUM_INPUT_QUEUES+NUM_INPUT_QUEUES_OFFSET)-1:NUM_INPUT_QUEUES_OFFSET]             = pkt_input_if;
	
	endmodule
