/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        stamp_counter.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_timestamp_v1_00_a
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
		output reg			gps_connected,

    		input [1:0]          	        restart_time,
    		input [TIMESTAMP_WIDTH-1:0]     ntp_timestamp,

		input				correction_mode,
		input				pps_rx,

    		input                           axi_aclk,
    		input                           axi_resetn
 	);



        localparam PPS = 27'h5F5E100;
        localparam OVERFLOW = 32'hffffffff;
	localparam CNT_INIT = 32'h1312d000;
        localparam DDS_WIDTH = 32;

   	reg [TIMESTAMP_WIDTH-6:0]	temp;
	wire[TIMESTAMP_WIDTH-1:0]	stamp_cnt;

        wire                            pps_valid;
        reg                             pps_rx_d1;
        reg                             pps_rx_d2;
        reg                             pps_rx_d3;

   	reg [DDS_WIDTH-1:0]             accumulator;
	reg [31:0]			counter;
   
        wire [DDS_WIDTH-1:0]            dds_rate;
 
   	assign stamp_counter = {temp,5'b0};
	assign stamp_cnt = {temp,5'b0};
  	assign pps_valid = !pps_rx_d2 & pps_rx_d3;


        correction
        #(
                .TIMESTAMP_WIDTH(TIMESTAMP_WIDTH),
                .DDS_WIDTH(DDS_WIDTH))
        correction
        (
        // input
                .time_pps      	(stamp_cnt),
                .pps_valid     	(pps_valid),
		.correction_mode(correction_mode),
        // output
                .dds      	(dds_rate),
        // misc
                .reset         	(~axi_resetn),
                .clk           	(axi_aclk)
        );


        always @(posedge axi_aclk) begin
                if (~axi_resetn) begin
                        pps_rx_d1  <= 0;
                	pps_rx_d2  <= 0;
                	pps_rx_d3  <= 0;
			counter		<= CNT_INIT;
			gps_connected	<= 0;
                end
                else begin
			pps_rx_d1 <= pps_rx;
                	pps_rx_d2 <= pps_rx_d1;
                	pps_rx_d3 <= pps_rx_d2;
			if(pps_valid) begin
				counter		<= CNT_INIT;
				gps_connected	<= 1;
			end
			else begin
				if(!counter)
					gps_connected <= 0;
				else begin
					gps_connected <= 1;
					counter	<= counter - 1;
				end
			end  
		end
	end


	always @(posedge axi_aclk) begin
        	if(~axi_resetn) begin
             		temp     <= 0;
             		accumulator <= 0;
        	end
		else begin
			if(restart_time[0])
             			temp<= ntp_timestamp[TIMESTAMP_WIDTH-1:5];
			else if (restart_time[1])
	     			temp<= 0;
        		else begin
             			if(OVERFLOW-accumulator<dds_rate)
                  			temp <= temp + 1;
              			accumulator <= accumulator + dds_rate;
			end
		end
        end

endmodule // stamp_counter




