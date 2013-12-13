/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        system_axisim_tb.v
 *
 *  Project:
 *        reference_nic
 *
 *  Module:
 *        system_axisim_tb
 *
 *  Author:
 *        James Hongyi Zeng
 *
 *  Description:
 *        System testbench for reference_nic
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

`timescale 1 ns / 1ps

`uselib lib=unisims_ver

// START USER CODE (Do not remove this line)

// User: Put your directives here. Code in this
//       section will not be overwritten.
`include "../../nf10/CY7C1515KV18.v"

// END USER CODE (Do not remove this line)

module system_axisim_tb
  (
  );

  // START USER CODE (Do not remove this line)

  // User: Put your signals here. Code in this
  //       section will not be overwritten.
  integer             i;

  // END USER CODE (Do not remove this line)

  reg RESET;
  wire RS232_Uart_1_sout;
  reg RS232_Uart_1_sin;
  reg CLK;
  reg refclk_A_p;
  reg refclk_A_n;
  reg refclk_B_p;
  reg refclk_B_n;
  reg refclk_C_p;
  reg refclk_C_n;
  reg refclk_D_p;
  reg refclk_D_n;
  wire MDC;
  wire MDIO;
  wire PHY_RST_N;
	wire [35:0] D0, D1;
	wire [35:0] Q0, Q1;
	wire [18:0] A0, A1;
	wire [3:0] BWS0b, BWS1b;
	wire WPSb0, WPSb1, 
	     RPSb0, RPSb1, 
			 DOFF0, DOFF1,
	     CQ0, CQ1,
			 CQb0, CQb1,
			 C0, C1,
			 Cb0, Cb1,
			 K0, K1,
			 Kb0, Kb1;
			 

  system_axisim
    dut (
      .RESET ( RESET ),
      .RS232_Uart_1_sout ( RS232_Uart_1_sout ),
      .RS232_Uart_1_sin ( RS232_Uart_1_sin ),
      .CLK ( CLK ),
      .refclk_A_p ( refclk_A_p ),
      .refclk_A_n ( refclk_A_n ),
      .refclk_B_p ( refclk_B_p ),
      .refclk_B_n ( refclk_B_n ),
      .refclk_C_p ( refclk_C_p ),
      .refclk_C_n ( refclk_C_n ),
      .refclk_D_p ( refclk_D_p ),
      .refclk_D_n ( refclk_D_n ),
      .MDC ( MDC ),
      .MDIO ( MDIO ),
      .PHY_RST_N ( PHY_RST_N ),
	    .qdr_d_0	(D0),
	    .qdr_q_0	(Q0),
	    .qdr_sa_0 (A0),
	    .qdr_w_n_0 (WPSb0),
	    .qdr_r_n_0 (RPSb0),
	    .qdr_bw_n_0 (BWS0b),
	    .qdr_dll_off_n_0 (DOFF0),
	    .qdr_cq_0 (CQ0),
	    .qdr_cq_n_0 (CQb0),
	    .qdr_c_n_0 (Cb0),
	    .qdr_k_n_0 (Kb0),
	    .qdr_c_0 (C0),
	    .qdr_k_0 (K0),
	    .qdr_masterbank_sel_0 (1),
	    .qdr_d_1 (D1),
	    .qdr_q_1 (Q1),
	    .qdr_sa_1 (A1),
	    .qdr_w_n_1 (WPSb1),
	    .qdr_r_n_1 (RPSb1),
	    .qdr_bw_n_1 (BWS1b),
	    .qdr_dll_off_n_1 (DOFF1),
	    .qdr_cq_1 (CQ1),
	    .qdr_cq_n_1 (CQb1),
	    .qdr_c_n_1 (Cb1),
	    .qdr_k_n_1 (Kb1),
	    .qdr_c_1 (C1),
	    .qdr_k_1 (K1),
	    .qdr_masterbank_sel_1 (0)
    );


  // START USER CODE (Do not remove this line)

  // User: Put your stimulus here. Code in this
  //       section will not be overwritten.

  // Part 1: Wire connection

  // Part 2: Reset
  initial begin
      RS232_Uart_1_sin = 1'b0;
      CLK   = 1'b0;

      refclk_A_p = 1'b0;
      refclk_A_n = 1'b1;
      refclk_B_p = 1'b0;
      refclk_B_n = 1'b1;
      refclk_C_p = 1'b0;
      refclk_C_n = 1'b1;
      refclk_D_p = 1'b0;
      refclk_D_n = 1'b1;

      $display("[%t] : System Reset Asserted...", $realtime);
      RESET = 1'b0;
      for (i = 0; i < 50; i = i + 1) begin
                 @(posedge CLK);
      end
      $display("[%t] : System Reset De-asserted...", $realtime);
      RESET = 1'b1;
  end

  // Part 3: Clock
  always #5  CLK = ~CLK;      // 100MHz
  always #3.2 refclk_A_p = ~refclk_A_p; // 156.25MHz
  always #3.2 refclk_A_n = ~refclk_A_n; // 156.25MHz
  always #3.2 refclk_B_p = ~refclk_B_p; // 156.25MHz
  always #3.2 refclk_B_n = ~refclk_B_n; // 156.25MHz
  always #3.2 refclk_C_p = ~refclk_C_p; // 156.25MHz
  always #3.2 refclk_C_n = ~refclk_C_n; // 156.25MHz
  always #3.2 refclk_D_p = ~refclk_D_p; // 156.25MHz
  always #3.2 refclk_D_n = ~refclk_D_n; // 156.25MHz

	// Part 4: Module instantiation
	cyqdr2_b4 sram_inst0 (
		.TCK (),
		.TMS (),
		.TDI (),
		.TDO (),
		.D (D0), 
		.Q (Q0), 
		.A (A0), 
		.K (K0), 
		.Kb (Kb0), 
		.C (C0), 
		.Cb (Cb0), 
		.RPSb (RPSb0), 
		.WPSb (WPSb0), 
		.BWS0b (BWS0b[0]), 
		.BWS1b (BWS0b[1]),
		.BWS2b (BWS0b[2]),
		.BWS3b (BWS0b[3]),
		.CQ (CQ0), 
		.CQb (CQb0),
		.ZQ (),
		.DOFF (DOFF0));
		
		cyqdr2_b4 sram_inst1 (
			.TCK (),
			.TMS (),
			.TDI (),
			.TDO (),
			.D (D1), 
			.Q (Q1), 
			.A (A1), 
			.K (K1), 
			.Kb (Kb1), 
			.C (C1), 
			.Cb (Cb1), 
			.RPSb (RPSb1), 
			.WPSb (WPSb1), 
			.BWS0b (BWS1b[0]), 
			.BWS1b (BWS1b[1]),
			.BWS2b (BWS1b[2]),
			.BWS3b (BWS1b[3]),
			.CQ (CQ1), 
			.CQb (CQb1),
			.ZQ (),
			.DOFF (DOFF1));
	
  // END USER CODE (Do not remove this line)

endmodule

