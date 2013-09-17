/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        stamp_counter.v
 *
 *  Library:
 *        contrib/pisa/pcores/nf10_timestamp_v1_00_a
 *
 *  Module:
 *        stamp_counter
 *
 *  Author:
 *        Gianni Antichi
 *
 *  Description:
 *        Stamp Counter module
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

module stamp_counter
	#(
    		parameter TIMESTAMP_WIDTH = 64)
	(
    
		output [TIMESTAMP_WIDTH-1:0]	stamp_counter,

    		input [1:0]          	        restart_time,
    		input [TIMESTAMP_WIDTH-1:0]     ntp_timestamp,

    		input                           axi_aclk,
    		input                           clk_correction,
    		input                           axi_resetn
 	);


   	reg [TIMESTAMP_WIDTH-6:0]	temp;

   	reg [TIMESTAMP_WIDTH-1:0]	time_pps;
   	reg                             pps_valid;

   	reg [DDS_WIDTH-1:0]             accumulator;
   	reg [26:0]                      counter_pps;

   	wire [TIMESTAMP_WIDTH-1:0]      time_pps_w;
   	wire                            pps_valid_w;
   
   	wire [DDS_WIDTH-1:0]            dds_rate;
	reg [DDS_WIDTH-1:0]		dds_sync,dds_aclk;	 
 

   	localparam PPS = 27'h5F5E100;
	localparam OVERFLOW = 32'hffffffff;
	localparam DDS_WIDTH = 32;
 
   	assign stamp_counter = {temp,5'b0};
   	assign time_pps_w = time_pps;
   	assign pps_valid_w = pps_valid;



	correction
	#(
   		.TIMESTAMP_WIDTH(TIMESTAMP_WIDTH),
		.DDS_WIDTH(DDS_WIDTH)) 
	correction
	(
	// input
        	.time_pps      (time_pps_w),
        	.pps_valid     (pps_valid_w),
     	// output
     		.dds_rate       (dds_rate),
     	// misc
     		.reset		(~axi_resetn),
        	.clk		(clk_correction)
     	);

	always @(posedge clk_correction) begin
     		if (~axi_resetn) begin
            		time_pps <= 0;
            		counter_pps <= 0;
      		end
      		else begin
			if(counter_pps==PPS) begin
				counter_pps <= 0;
				pps_valid   <= 1;
				time_pps    <= stamp_counter;
			end
			else begin
				counter_pps <= counter_pps + 1;
            			pps_valid <= 0;
      			end
   		end
	end   

	always @(posedge axi_aclk) begin
        	if(~axi_resetn) begin
             		temp     <= 0;
             		accumulator <= 0;
			dds_sync <= 0;
			dds_aclk <= 0;
        	end
		else begin
			dds_sync <= dds_rate;
                	dds_aclk <= dds_sync;
			if(restart_time[0])
             			temp<= ntp_timestamp[TIMESTAMP_WIDTH-1:5];
			else if (restart_time[1])
	     			temp<= 0;
        		else begin
             			if(OVERFLOW-accumulator<dds_aclk)
                  			temp <= temp + 1;
              			accumulator <= accumulator + dds_aclk;
			end
		end
        end

endmodule // stap_counter




