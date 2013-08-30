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

	 `include "global_defines.v"

	 module ETH_IPv4_GRE_PPPC_IPv4_TCPnUDP 
   (// --- Interface to the previous stage
    input  [`DATA_WIDTH-1:0]                in_data,
    input																	 in_wr,
    input																	 in_sop,
    input																	 in_eop,
    input																	 in_eoh,
    
    // --- Results 
    output reg														 pkt_valid,
   	output 		 [`PIPELINE_DATA_WIDTH-1:0]	 pkt_attributes,
   																										
    // --- Misc
    input                                  reset,
    input                                  clk 
	 );
	 
	 //------------------ Internal Parameter ---------------------------
	 
	 localparam IDLE			 		= 4'd0,
	 						PKT_WORD0  		= 4'd1,
	 						PKT_WORD1	 		= 4'd2,
	 						PKT_WORD2	 		= 4'd3,
	 						PKT_WORD3			= 4'd4,
	 						PKT_WORD4     = 4'd5,
	 						PKT_WORD5     = 4'd6,
	 						PKT_WAIT_HDR  = 4'd7,
	 						PKT_WAIT_EOP  = 4'd8;
	 
	 //---------------------- Wires/Regs -------------------------------
	 
	 reg [`DATA_WIDTH-1:0] 				in_data_d0;	 
	 reg													in_wr_d0; 
	 reg													in_sop_d0;
	 reg													in_eop_d0;	
	 reg													in_eoh_d0; 
	 	                    				
	 reg [3:0]										pkt_ip_hdr_len_0;	 
	 reg [3:0]										pkt_ip_hdr_len_1;
	 reg [3:0]										pkt_gre_hdr_len; 
	 reg [3:0]										pkt_tcp_hdr_len; 	 
   reg [`IP_WIDTH-1:0]					pkt_src_ip;
   reg [`IP_WIDTH-1:0]					pkt_dst_ip;
   reg [`PORT_WIDTH-1:0]				pkt_src_port;
   reg [`PORT_WIDTH-1:0]				pkt_dst_port;
   reg [`PKT_FLAGS-1:0]	  			pkt_flags;
   reg [`NUM_INPUT_QUEUES-1:0] 	pkt_input_if;
	 
	 reg													pkt_valid_w;
	 reg [3:0]										pkt_ip_hdr_len_w_0;
	 reg [3:0]										pkt_ip_hdr_len_w_1;
	 reg [3:0]										pkt_gre_hdr_len_w;
	 reg [`IP_WIDTH-1:0]					pkt_src_ip_w;
	 reg [`IP_WIDTH-1:0]					pkt_dst_ip_w;  
	 reg [3:0]										pkt_tcp_hdr_len_w;
	 reg [`PORT_WIDTH-1:0]				pkt_src_port_w;
	 reg [`PORT_WIDTH-1:0]				pkt_dst_port_w;
	 reg [`PKT_FLAGS-1:0]  				pkt_flags_w;
	 reg [`NUM_INPUT_QUEUES-1:0] 	pkt_input_if_w;
	 
	 reg [3:0] 										cur_state;
	 reg [3:0]										nxt_state;
	 
	 //------------------------ Logic ----------------------------------
	 
 always @ (posedge clk or posedge reset)
	 begin
	 	if (reset)
	 	begin	 		
	 		in_wr_d0 <= 1'b0;	 		
	 		in_sop_d0 <= 1'b0;
	 		in_eop_d0 <= 1'b0;
	 		in_eoh_d0 <= 1'b0;
	 	end
	 	else 
	 	begin	 		
	 		in_wr_d0 <= in_wr;	 		
	 		in_sop_d0 <= in_sop;
	 		in_eop_d0 <= in_eop;
	 		in_eoh_d0 <= in_eoh;
	 	end
	 end
	 
	 always @ (posedge clk)
	 begin
	 	in_data_d0 <= in_data;	 		
	 end
	 
	 always @ (*)
	 begin  
	 		nxt_state = cur_state;
	 		pkt_valid_w = 1'b0;
	 		pkt_ip_hdr_len_w_0 = pkt_ip_hdr_len_0;
	 		pkt_ip_hdr_len_w_1 = pkt_ip_hdr_len_1;
	 		pkt_gre_hdr_len_w = pkt_gre_hdr_len;
	 		pkt_src_ip_w = pkt_src_ip;
	 		pkt_dst_ip_w = pkt_dst_ip;
	 		pkt_tcp_hdr_len_w = pkt_tcp_hdr_len;
	 		pkt_src_port_w = pkt_src_port;
	 		pkt_dst_port_w = pkt_dst_port;
	 		pkt_flags_w = pkt_flags;
	 		pkt_input_if_w = pkt_input_if;
	 	
	 		case (cur_state)		 		
	 		IDLE:
	 		begin	 			
	 		
	 			pkt_ip_hdr_len_w_0 = 4'b0;
	 			pkt_ip_hdr_len_w_1 = 4'b0;
	 			pkt_gre_hdr_len_w = 4'b0;
	 			pkt_src_ip_w = {`IP_WIDTH{1'b0}};   
				pkt_dst_ip_w = {`IP_WIDTH{1'b0}};  
				pkt_tcp_hdr_len_w = 4'b0;
	 			pkt_src_port_w = {`PORT_WIDTH{1'b0}}; 
				pkt_dst_port_w = {`PORT_WIDTH{1'b0}};
				pkt_flags_w = {`PKT_FLAGS{1'b0}}; 
				pkt_input_if_w = {`NUM_INPUT_QUEUES{1'b0}};
							
	 			if (in_sop_d0 && in_wr_d0)
	 			begin
	 				nxt_state = PKT_WORD0;
	 				pkt_input_if_w = in_data_d0[`NUM_INPUT_QUEUES+`IOQ_SRC_PORT_POS-1:`IOQ_SRC_PORT_POS];
	 			end
	 		end

	 		
	 		PKT_WORD0:
	 		begin		 	
	 			if (in_wr_d0)
	 			begin
		 			pkt_flags_w[`PKT_FLG_IPv4] = (in_data_d0[31:16] == `ETH_IP);	
		 			if (pkt_flags_w[`PKT_FLG_IPv4])
		 			begin
		 				pkt_ip_hdr_len_w_0 = in_data_d0[11:8]; // in 32 bit words

		 				nxt_state = PKT_WORD1;
		 			end
		 			else
		 				nxt_state = IDLE;
		 		end
	 		end
	 		
	 		PKT_WORD1:
	 		begin		
	 			if (in_wr_d0)
	 			begin
	 				pkt_flags_w[`PKT_FLG_FRG] = (in_data_d0[93] || (in_data_d0[92:80] != 14'd0));
	 				if (!pkt_flags_w[`PKT_FLG_FRG])
	 				begin	 					
	 					pkt_flags_w[`PKT_FLG_GRE] = (in_data_d0[71:64] == `IP_GRE);
			 			if (pkt_flags_w[`PKT_FLG_GRE])

			 				nxt_state = PKT_WORD2;
			 			else
			 				nxt_state = IDLE;
			 		end
			 		else
			 			nxt_state = IDLE;
		 		end
	 		end
	 		
	 		PKT_WORD2:
	 		begin		
	 			if (in_wr_d0)
	 			begin
	 				case(pkt_ip_hdr_len_0)
	 				4'd5:
	 				begin
	 					case(in_data_d0[111:108])
		 				4'b0000: //{checksum = 0, routing = 0, key = 0, sequence no = 0}						
		 				begin
		 					pkt_gre_hdr_len_w = 4'b0;
	 						pkt_flags_w[`PKT_FLG_PPPC] = (in_data_d0[95:80] == `GRE_PPPC);
	 						if(pkt_flags_w[`PKT_FLG_PPPC])
	 						begin
	 							pkt_flags_w[`PKT_FLG_IPv4] = (in_data_d0[79:72] == `PPPC_IP);
	 							if(pkt_flags_w[`PKT_FLG_IPv4])
	 							begin
	 								pkt_ip_hdr_len_w_1 = in_data_d0[67:64];
	 								pkt_flags_w[`PKT_FLG_FRG] = (in_data_d0[21] || (in_data_d0[20:8] != 14'd0));

		 							nxt_state = PKT_WORD3;
			 					end
			 					else
			 						nxt_state = IDLE;
			 				end
			 				else
			 					nxt_state = IDLE;
			 			end
			 			default:// add remaining cases of gre
			 				nxt_state = IDLE;
			 			endcase
	 				end
	 				default: // to add the remaining cases of ip len
	 					nxt_state = IDLE;
	 				endcase
		 		end
	 		end
	 				
	 		PKT_WORD3:
	 		begin		 	
	 			if (in_wr_d0)
	 			begin
	 				case(pkt_ip_hdr_len_0)
	 				4'd5:
	 				begin
	 					case(pkt_gre_hdr_len)
	 					4'd0:
	 						begin
		 					pkt_flags_w[`PKT_FLG_TCP] = (in_data_d0[127:120] == `IP_TCP);
	 						pkt_flags_w[`PKT_FLG_UDP] = (in_data_d0[127:120] == `IP_UDP);
	 						pkt_src_ip_w = in_data_d0[103:72];
		 					pkt_dst_ip_w = in_data_d0[71:40];
		 					if (!pkt_flags[`PKT_FLG_FRG])
			 				begin	
				 				if (pkt_flags_w[`PKT_FLG_TCP] || pkt_flags_w[`PKT_FLG_UDP])
				 				begin	
				 					case(pkt_ip_hdr_len_1)
				 					4'd5:
				 					begin
				 						pkt_src_port_w = in_data_d0[39:24];
				 						pkt_dst_port_w = in_data_d0[23:8];
				 						if (in_eop_d0) /*small pkt*/
										begin
											pkt_valid_w = 1'b1;
											nxt_state = IDLE;
										end
										else
				 							nxt_state = PKT_WORD4;
					 				end
					 				default:
					 				begin
					 					pkt_src_port_w = {`PORT_WIDTH{1'b0}};
					 					pkt_dst_port_w = {`PORT_WIDTH{1'b0}};
					 					if (in_eop_d0) /*small pkt*/
										begin
											pkt_valid_w = 1'b1;
											nxt_state = IDLE;
										end
										else
					 						nxt_state = PKT_WAIT_HDR;
				 					end
				 					endcase
				 				end
				 				else
				 					nxt_state = IDLE;	
				 			end
				 			else if (in_eop_d0) /*small pkt*/
							begin
								pkt_valid_w = 1'b1;
								nxt_state = IDLE;
							end
							else
				 				nxt_state = PKT_WAIT_HDR;
				 		end
				 		default: // to add the remaining cases
				 			nxt_state = IDLE;
				 		endcase	
			 		end
	 				default: // to add the remaining cases
	 					nxt_state = IDLE;
	 				endcase
		 		end		 		
	 		end
	 		
	 		PKT_WORD4:
	 		begin		
	 			if (in_wr_d0)
	 			begin
	 				if (pkt_flags[`PKT_FLG_UDP])
			 		begin
			 			pkt_flags_w[`PKT_FLG_RTP] = (in_data_d0[103:100] == `UDP_RTP);
			 			if (in_eop_d0) /*small pkt*/
						begin
							pkt_valid_w = 1'b1;
							nxt_state = IDLE;
						end
						else
			 				nxt_state = PKT_WAIT_HDR;
			 		end
 					else if (pkt_flags[`PKT_FLG_TCP])
 					begin
 						pkt_tcp_hdr_len_w = in_data_d0[71:68]; // in 32 bit words
		 				case(pkt_tcp_hdr_len_w)
				 		4'd5:
				 		begin	 
				 			pkt_flags_w[`PKT_FLG_GET] = (in_data_d0[7:0] == `TCP_G);
			 				pkt_flags_w[`PKT_FLG_POST] = (in_data_d0[7:0] == `TCP_P);
							if (in_eop_d0) /*small pkt*/
							begin
								pkt_valid_w = 1'b1;
								nxt_state = IDLE;
							end
							else
	 							nxt_state = PKT_WORD5;
	 					end
	 					default: // to add the remaining cases
			 			begin
			 				if (in_eop_d0) /*small pkt*/
							begin
								pkt_valid_w = 1'b1;
								nxt_state = IDLE;
							end
							else
				 				nxt_state = PKT_WAIT_HDR;
			 			end
			 			endcase
		 			end
					else if (in_eop_d0) /*small pkt*/
					begin
						pkt_valid_w = 1'b1;
						nxt_state = IDLE;
					end
					else
			 		nxt_state = PKT_WAIT_HDR;	
	 			end
	 		end 		
	 
	 		PKT_WORD5:
	 		begin		
	 			if (in_wr_d0)
	 			begin
					case(pkt_tcp_hdr_len)
				 	4'd5:
				 	begin
				 		pkt_flags_w[`PKT_FLG_GET] = (pkt_flags[`PKT_FLG_GET] & (in_data_d0[127:112] == `TCP_ET));
			 			pkt_flags_w[`PKT_FLG_POST] = (pkt_flags[`PKT_FLG_POST] & (in_data_d0[127:104] == `TCP_OST));
			 			
			 			if (in_eop_d0) /*small pkt*/
						begin
							pkt_valid_w = 1'b1;
							nxt_state = IDLE;
						end
						else
	 						nxt_state = PKT_WAIT_HDR;
	 				end
	 				default: // to add the remaining cases
			 		begin
			 			if (in_eop_d0) /*small pkt*/
						begin
							pkt_valid_w = 1'b1;
							nxt_state = IDLE;
						end
						else
			 				nxt_state = PKT_WAIT_HDR;
			 		end
			 		endcase
	 			end
	 		end

	 		PKT_WAIT_HDR:
	 		begin
	 			if (in_wr_d0)
	 			begin
		 			if (in_eop_d0) /*small pkt*/
		 			begin
		 				pkt_valid_w = 1'b1;
		 				nxt_state = IDLE;
		 			end
		 			else if (in_eoh_d0)
		 			begin
		 				pkt_valid_w = 1'b1;
		 				nxt_state = PKT_WAIT_EOP;
		 			end
		 		end
	 		end
	 		
	 		PKT_WAIT_EOP:
	 		begin
	 			if (in_wr_d0 && in_eop_d0)
	 				nxt_state = IDLE;
	 		end
	 		
	 		endcase
	 end
	 
	 
	 always @ (posedge clk or posedge reset)
	 begin
	 		if (reset)
	 		begin
	 			cur_state <= IDLE;
	 			
	 			pkt_valid <= 1'b0;	 			 			
	 			pkt_ip_hdr_len_0 <= 4'b0;
	 			pkt_ip_hdr_len_1 <= 4'b0;
	 			pkt_gre_hdr_len <= 4'b0;
	 			pkt_src_ip <= {`IP_WIDTH{1'b0}};   
				pkt_dst_ip <= {`IP_WIDTH{1'b0}};  
				pkt_tcp_hdr_len <= 4'b0;
	 			pkt_src_port <= {`PORT_WIDTH{1'b0}}; 
				pkt_dst_port <= {`PORT_WIDTH{1'b0}};
				pkt_flags <= {`PKT_FLAGS{1'b0}};
				pkt_input_if <= {`NUM_INPUT_QUEUES{1'b0}};
	 		end   
	 		else
	 		begin
	 			cur_state <= nxt_state;
	 			
	 			pkt_valid <= pkt_valid_w;	
	 			pkt_ip_hdr_len_0 <= pkt_ip_hdr_len_w_0;
	 			pkt_ip_hdr_len_1 <= pkt_ip_hdr_len_w_1;
	 			pkt_gre_hdr_len <= pkt_gre_hdr_len_w;
	 			pkt_src_ip <= pkt_src_ip_w;   
				pkt_dst_ip <= pkt_dst_ip_w;  
				pkt_tcp_hdr_len <= pkt_tcp_hdr_len_w;
	 			pkt_src_port <= pkt_src_port_w; 
				pkt_dst_port <= pkt_dst_port_w;
				pkt_flags <= pkt_flags_w;
				pkt_input_if <= pkt_input_if_w;
	 		end
	 end 
	 
	 assign pkt_attributes[(`IP_WIDTH+`IP_SRC_OFFSET)-1:`IP_SRC_OFFSET] 				= pkt_src_ip;
	 assign pkt_attributes[(`IP_WIDTH+`IP_DST_OFFSET)-1:`IP_DST_OFFSET] 				= pkt_dst_ip;
	 assign pkt_attributes[(`PORT_WIDTH+`PORT_SRC_OFFSET)-1:`PORT_SRC_OFFSET] 	= pkt_src_port;
	 assign pkt_attributes[(`PORT_WIDTH+`PORT_DST_OFFSET)-1:`PORT_DST_OFFSET] 	= pkt_dst_port;
	 assign pkt_attributes[(`PKT_FLAGS+`PKT_FLAGS_OFFSET)-1:`PKT_FLAGS_OFFSET] = pkt_flags;
	 assign pkt_attributes[(`PRTCL_ID_WIDTH+`PRTCL_ID_OFFSET)-1:`PRTCL_ID_OFFSET] = `PRIORITY_ETH_IPv4_GRE_PPPC_IPv4_TCPnUDP;           
	 assign pkt_attributes[(`NUM_INPUT_QUEUES+`PKT_INPUT_IF_ONE_HOT_OFFSET)-1:`PKT_INPUT_IF_ONE_HOT_OFFSET] = pkt_input_if;
	 
	 endmodule