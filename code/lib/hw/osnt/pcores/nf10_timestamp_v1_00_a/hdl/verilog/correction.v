/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        correction.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_timestamp_v1_00_a
 *
 *  Module:
 *        correction
 *
 *  Author:
 *        Gianni Antichi
 *
 *  Description:
 *        Timestamp Correction Module.
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

  
module correction
	#(parameter TIMESTAMP_WIDTH = 64,
	  parameter DDS_WIDTH = 32)
   	(
    	// input
    		input [TIMESTAMP_WIDTH-1:0]     time_pps,
    		input                           pps_valid,
		input				correction_mode,

    	// output
    		output reg [DDS_WIDTH-1:0]	dds,

    	// misc
    		input                           reset,
    		input                           clk
    	);
          
  
	localparam NUM_STATES	      = 3;
     	localparam WAIT_FIRST_PPS     = 1;
     	localparam WAIT_PPS           = 2;
     	localparam UPDATE_DDS 	      = 4;
	localparam CORRECTION_WEIGHT  = 10;
	localparam DDS_RATE_DEFAULT   = 32'hd6bf94d6; 


	reg [NUM_STATES-1:0]     state,state_next;
	reg [TIMESTAMP_WIDTH-1:0]time_prev_pps,time_prev_pps_next;
     	reg [DDS_WIDTH-1:0]      dds_rate,dds_rate_next;
     	reg [TIMESTAMP_WIDTH-1:0]error_signed,error_signed_next;
 
    

    	always @(*) begin
     		state_next = state;
     		dds_rate_next = dds_rate;
     		time_prev_pps_next = time_prev_pps;
    		error_signed_next = time_pps - time_prev_pps;  

		case(state)
        	WAIT_FIRST_PPS: begin
        		if(pps_valid) begin
                		time_prev_pps_next  = time_pps;
				state_next = WAIT_PPS;
           		end
        	end

		WAIT_PPS: begin
        		if(pps_valid) begin
				time_prev_pps_next = time_pps;
                		state_next = UPDATE_DDS;
			end
        	end

        	UPDATE_DDS: begin
			if(error_signed[TIMESTAMP_WIDTH-1])
				state_next = WAIT_FIRST_PPS;
			else begin
				state_next = WAIT_PPS;
        			if(error_signed[TIMESTAMP_WIDTH-2:32])
               				dds_rate_next = dds_rate - (error_signed[31:0]>>CORRECTION_WEIGHT);
	    			else
               				dds_rate_next = dds_rate + ((~error_signed[31:0])>>CORRECTION_WEIGHT);
			end
         	end
       		endcase
	end


   	always @(posedge clk) begin
        	if(reset) begin
	     		dds_rate    	<= DDS_RATE_DEFAULT;
			dds		<= DDS_RATE_DEFAULT;
             		error_signed	<= 0;
             		time_prev_pps	<= 0;
             		state       	<= WAIT_FIRST_PPS;
        	end
		else begin
             		error_signed	<= error_signed_next;
             		time_prev_pps 	<= time_prev_pps_next;
			state		<= state_next;
			dds_rate	<= dds_rate_next;
			if(correction_mode)
				dds	<= dds_rate;
        	end
   	end

endmodule // correction
