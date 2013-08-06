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

	 module ETH_MPLS_MPLS_IPv4_TCPnUDP 
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
	 
	 localparam IDLE			 		= 3'd0,
	 						PKT_WORD0  		= 3'd1,
	 						PKT_WORD1	 		= 3'd2,
	 						PKT_WORD2	 		= 3'd3,
	 						PKT_WORD3	 		= 3'd4,
	 						PKT_WORD4	 		= 3'd5,
	 						PKT_WAIT_HDR  = 3'd6,
	 						PKT_WAIT_EOP  = 3'd7;
	 
	 //---------------------- Wires/Regs -------------------------------
	 
	 reg [`DATA_WIDTH-1:0] 				in_data_d0;	 
	 reg													in_wr_d0; 
	 reg													in_sop_d0;
	 reg													in_eop_d0;	 
	 reg													in_eoh_d0; 
                        				
	 reg [3:0]										pkt_ip_hdr_len;	 
	 reg [3:0]										pkt_tcp_hdr_len;	 	 
   reg [`IP_WIDTH-1:0]					pkt_src_ip;
   reg [`IP_WIDTH-1:0]					pkt_dst_ip;
   reg [`PORT_WIDTH-1:0]				pkt_src_port;
   reg [`PORT_WIDTH-1:0]				pkt_dst_port;
   reg [`PKT_FLAGS-1:0]	  			pkt_flags;
   reg [`NUM_INPUT_QUEUES-1:0] 	pkt_input_if;
	 
	 reg													pkt_valid_w;
	 reg [3:0]										pkt_ip_hdr_len_w;
	 reg [`IP_WIDTH-1:0]					pkt_src_ip_w;
	 reg [`IP_WIDTH-1:0]					pkt_dst_ip_w;  
	 reg [3:0]										pkt_tcp_hdr_len_w;
	 reg [`PORT_WIDTH-1:0]				pkt_src_port_w;
	 reg [`PORT_WIDTH-1:0]				pkt_dst_port_w;
	 reg [`PKT_FLAGS-1:0]  				pkt_flags_w;
	 reg [`NUM_INPUT_QUEUES-1:0] 	pkt_input_if_w;
	 
	 reg [2:0] 										cur_state;
	 reg [2:0]										nxt_state;
	 
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
	 		pkt_ip_hdr_len_w = pkt_ip_hdr_len;
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
	 			pkt_ip_hdr_len_w = 4'b0;
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
		 			pkt_flags_w[`PKT_FLG_MPLS] = (in_data_d0[31:16] == `ETH_MPLS);	
		 			if (pkt_flags_w[`PKT_FLG_MPLS])
		 			begin		 				
		 			
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
	 				if ((in_data_d0[120] == 1'b0) && (in_data_d0[88] == 1'b1)/*MPLS bottom of label stack bit*/)
	 				begin
		 				pkt_flags_w[`PKT_FLG_IPv4] = ( (in_data_d0[79:76] == `IP_VER4)/*Version = 4*/ 
		 															 &&(in_data_d0[75:72]	== 	4'd5)/*Header Length = 5*/);
		 				if(pkt_flags_w[`PKT_FLG_IPv4])
		 				begin
			 				pkt_ip_hdr_len_w = in_data_d0[75:72]; // in 32 bit words
		 					pkt_flags_w[`PKT_FLG_FRG] = (in_data_d0[29] || (in_data_d0[28:16] != 14'd0));
				 			pkt_flags_w[`PKT_FLG_TCP] = (in_data_d0[7:0] == `IP_TCP);
				 			pkt_flags_w[`PKT_FLG_UDP] = (in_data_d0[7:0] == `IP_UDP);
				 			
				 			nxt_state = PKT_WORD2;
				 		end
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
		 			pkt_src_ip_w = in_data_d0[111:80];
		 			pkt_dst_ip_w = in_data_d0[79:48];
		 			
		 			if (!pkt_flags[`PKT_FLG_FRG])
		 			begin
			 			if (pkt_flags[`PKT_FLG_TCP] || pkt_flags[`PKT_FLG_UDP])
			 			begin	
			 				case(pkt_ip_hdr_len)
			 				4'd5:
			 				begin
			 					pkt_src_port_w = in_data_d0[47:32];
			 					pkt_dst_port_w = in_data_d0[31:16];
			 					
			 					nxt_state = PKT_WORD3;
			 				end
			 				default:
			 				begin
			 					pkt_src_port_w = {`PORT_WIDTH{1'b0}};
			 					pkt_dst_port_w = {`PORT_WIDTH{1'b0}};
			
			 					nxt_state = PKT_WAIT_HDR;
			 				end
			 				endcase
			 			end
			 			else
			 				nxt_state = IDLE;
			 		end
			 		else
			 		
			 			nxt_state = PKT_WAIT_HDR;
		 		end
	 		end
	 		
	 		PKT_WORD3:
	 		begin		
	 			if (in_wr_d0)
	 			begin
	 				if (pkt_flags[`PKT_FLG_UDP])
			 		begin
			 			pkt_flags_w[`PKT_FLG_RTP] = (in_data_d0[111:108] == `UDP_RTP);
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
 						pkt_tcp_hdr_len_w = in_data_d0[79:76]; // in 32 bit words
		 				case(pkt_tcp_hdr_len_w)
				 		4'd5:
				 		begin	 
				 			pkt_flags_w[`PKT_FLG_GET] = (in_data_d0[15:0] == `TCP_GE);
			 				pkt_flags_w[`PKT_FLG_POST] = (in_data_d0[15:0] == `TCP_PO);
							
							if (in_eop_d0) /*small pkt*/
							begin
								pkt_valid_w = 1'b1;
								nxt_state = IDLE;
							end
							else
								nxt_state = PKT_WORD4;
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
	 			 
	 		PKT_WORD4:
	 		begin		
	 			if (in_wr_d0)
	 			begin
					case(pkt_tcp_hdr_len)
				 	4'd5:
				 	begin
				 		pkt_flags_w[`PKT_FLG_GET] = (pkt_flags[`PKT_FLG_GET] & (in_data_d0[127:120] == `TCP_T));
			 			pkt_flags_w[`PKT_FLG_POST] = (pkt_flags[`PKT_FLG_POST] & (in_data_d0[127:112] == `TCP_ST));
			 			
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
	 			pkt_ip_hdr_len <= 4'b0;
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
	 			pkt_ip_hdr_len <= pkt_ip_hdr_len_w;
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
	 assign pkt_attributes[(`PRTCL_ID_WIDTH+`PRTCL_ID_OFFSET)-1:`PRTCL_ID_OFFSET] = `PRIORITY_ETH_MPLS_MPLS_IPv4_TCPnUDP;           
	 assign pkt_attributes[(`NUM_INPUT_QUEUES+`PKT_INPUT_IF_ONE_HOT_OFFSET)-1:`PKT_INPUT_IF_ONE_HOT_OFFSET] = pkt_input_if;

	 endmodule