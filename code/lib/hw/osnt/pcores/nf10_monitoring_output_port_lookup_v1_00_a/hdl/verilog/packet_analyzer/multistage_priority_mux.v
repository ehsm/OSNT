/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        multistage_priority_mux.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_monitoring_output_port_lookup_v1_00_a
 *
 *  Module:
 *        multistage_priority_mux
 *
 *  Author:
 *        Muhammad Shahbaz
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

	module multistage_priority_mux 
	#(
		parameter ATTRIBUTE_DATA_WIDTH	= 135,
	 	parameter DIVISION_FACTOR 	= 2,
	 	parameter DATA_GROUPS		= 4
	)
   	(// --- Results 
    		output 						valid_o,
   		output [ATTRIBUTE_DATA_WIDTH-1:0]		data_o,
   	
   		input [DATA_GROUPS-1:0]				valid_groups_i,
   		input [(DATA_GROUPS*ATTRIBUTE_DATA_WIDTH)-1:0]	data_groups_i,
			 																																   	    
    	// --- Misc
    		input                                  		reset,
    		input                                  		clk 
	);
	
 
	// Log Functions
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
	 
	 
	//---------------------- Wires/Regs -------------------------------   
   
	generate
   		genvar i;
   		for (i=0; i<DATA_GROUPS; i=i+1)	begin: DATA_GROUPS_W
	 		wire	 			valid_int;
	 		wire [ATTRIBUTE_DATA_WIDTH-1:0]	data_int;
	 		
   			assign valid_int = valid_groups_i[i];
   			assign data_int  = data_groups_i[(i*ATTRIBUTE_DATA_WIDTH)+ATTRIBUTE_DATA_WIDTH-1:(i*ATTRIBUTE_DATA_WIDTH)];
   		end   
 	 endgenerate  
	 
	//------------------------ Logic ----------------------------------
 	 
 	generate
   		genvar k,l,m;
   		for (k=0; k<=log2(DIVISION_FACTOR); k=k+1) begin: MUX_COLUMN_W
   			for (l=0; l<(DIVISION_FACTOR/(2**k)); l=l+1) begin: MUX_BLOCK_W
	   			reg				valid;
				reg [ATTRIBUTE_DATA_WIDTH-1:0]	data;
				
				if (k==0) begin: MUX_BLOCK_W_IF
					for (m=0; m<(DATA_GROUPS/DIVISION_FACTOR); m=m+1) begin: MUX_BLOCK_I
 						wire				valid;
				   		wire [ATTRIBUTE_DATA_WIDTH-1:0]	data;			   	
		       
		       				if (m==0) begin: MUX_BLOCK_I_IF                      
		     		 			assign valid = (DATA_GROUPS_W[((DATA_GROUPS/DIVISION_FACTOR)*l)+m].valid_int) 
		     		 											? 1'b1
		     		 											: 1'b0;
		     		 			assign data = (DATA_GROUPS_W[((DATA_GROUPS/DIVISION_FACTOR)*l)+m].valid_int)
		     		 											? DATA_GROUPS_W[((DATA_GROUPS/DIVISION_FACTOR)*l)+m].data_int
		     		 											: {ATTRIBUTE_DATA_WIDTH{1'b0}};
		   		 		end
		   		 		else begin: MUX_BLOCK_I_IF
		   		 	 		assign valid = (DATA_GROUPS_W[((DATA_GROUPS/DIVISION_FACTOR)*l)+m].valid_int) 
		     		 											? 1'b1
		     		 											: MUX_COLUMN_W[k].MUX_BLOCK_W[l].MUX_BLOCK_W_IF.MUX_BLOCK_I[m-1].valid;
		     		 			assign data = (DATA_GROUPS_W[((DATA_GROUPS/DIVISION_FACTOR)*l)+m].valid_int)
		     		 											? DATA_GROUPS_W[((DATA_GROUPS/DIVISION_FACTOR)*l)+m].data_int
		     		 											: MUX_COLUMN_W[k].MUX_BLOCK_W[l].MUX_BLOCK_W_IF.MUX_BLOCK_I[m-1].data;
		   		 		end
 					end
 					
 					always @(posedge clk or posedge reset) begin
			 			if (reset) begin
			 				valid 	<= 1'b0;   
							data 	<= {ATTRIBUTE_DATA_WIDTH{1'b0}};
			 			end
						else begin 	 			
							valid 	<= MUX_COLUMN_W[k].MUX_BLOCK_W[l].MUX_BLOCK_W_IF.MUX_BLOCK_I[(DATA_GROUPS/DIVISION_FACTOR)-1].valid;   
							data 	<= MUX_COLUMN_W[k].MUX_BLOCK_W[l].MUX_BLOCK_W_IF.MUX_BLOCK_I[(DATA_GROUPS/DIVISION_FACTOR)-1].data;
						end
				 	end  		
				end
				
				else begin: MUX_BLOCK_W_IF
					always @(posedge clk or posedge reset) begin
			 			if (reset) begin
			 				valid <= 1'b0;   
							data <= {ATTRIBUTE_DATA_WIDTH{1'b0}};
			 			end
			 			else begin 
			 				valid <= 1'b0;   
							data <= {ATTRIBUTE_DATA_WIDTH{1'b0}};
			 				
			 				if (MUX_COLUMN_W[k-1].MUX_BLOCK_W[(l*2)+1].valid) begin
								valid <= 1'b1;   
								data <= MUX_COLUMN_W[k-1].MUX_BLOCK_W[(l*2)+1].data;
							end
			 				else if (MUX_COLUMN_W[k-1].MUX_BLOCK_W[l*2].valid) begin
								valid <= 1'b1;   
								data <= MUX_COLUMN_W[k-1].MUX_BLOCK_W[l*2].data;
							end
			 			end
			 		end
				end
			end
   		end
	endgenerate
   
 	 
	assign valid_o	= MUX_COLUMN_W[log2(DIVISION_FACTOR)].MUX_BLOCK_W[0].valid;    
	assign data_o  	= MUX_COLUMN_W[log2(DIVISION_FACTOR)].MUX_BLOCK_W[0].data;   

	endmodule
