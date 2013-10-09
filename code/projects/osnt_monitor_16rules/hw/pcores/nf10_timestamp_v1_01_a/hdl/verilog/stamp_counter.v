/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        stamp_counter.v
 *
 *  Library:
 *        hw/contrib/pisa/pcores/nf10_timestamp_v1_01_a
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
    		input                           axi_resetn
 	);


   	reg [TIMESTAMP_WIDTH-1:0]	time_counter;


 
   	assign stamp_counter = time_counter;

	always @(posedge axi_aclk) begin
		if(~axi_resetn)
             		time_counter     <= 0;
		else begin
			if(restart_time[0])
             			time_counter<= ntp_timestamp;
			else if (restart_time[1])
	     			time_counter<= 0;
        		else
				time_counter<= time_counter + 1;
		end
        end

endmodule // stap_counter




