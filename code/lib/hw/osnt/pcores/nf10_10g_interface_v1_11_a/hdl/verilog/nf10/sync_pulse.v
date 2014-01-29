/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        sync_pulse.v
 *
 *  Library:
 *        hw/std/pcores/nf10_10g_interface_v1_11_a
 *
 *  Module:
 *        sync_pulse
 *
 *  Author:
 *        Yury Audzevich
 *
 *  Description:
 *        MAC-CORE clk pulse synchronizer
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


`timescale 1ns / 1ps
module sync_pulse(
	input  clkA,
	input  rstA,
	input  pulseA,
	
	input  clkB,
	input  rstB,
	output pulseB,
	
	output pulseA_busy
);

// filter input pulse in clkA
// input pulse ^ (latched pulse & ~busy transfering pulse)
reg t_pulseA;
always @ (posedge clkA) begin
	if (rstA)  	t_pulseA <= 0; 
	else 			t_pulseA <= t_pulseA ^ (pulseA & ~pulseA_busy);
end

// transfer pulseA in clkB
// use simple shift register; output [2] element
reg [2:0] pulseA_clkB; // at least 3 elements
always @ (posedge clkB) begin
	if	(rstB) pulseA_clkB <= 'b0;
	else 		 pulseA_clkB <= {pulseA_clkB[1:0], t_pulseA};
end

//pulse filter in clkB and output
assign pulseB = pulseA_clkB[2] ^ pulseA_clkB[1];


// pulseB is transfer back to clkA for feedback (form busy period)
// same as above but in clkA, i.e. put pulseA in clkB into shift reg
reg [1:0] pulseB_clkA;
always @ (posedge clkA) begin
	if	(rstA) pulseB_clkA <= 'b0;
	else 		 pulseB_clkA <= {pulseB_clkA[0], pulseA_clkB[2]};
end

//busy period = (RTT time clkA->clkB->clkA  - latched in clkA)
assign pulseA_busy = pulseB_clkA[1] ^ t_pulseA;


endmodule
