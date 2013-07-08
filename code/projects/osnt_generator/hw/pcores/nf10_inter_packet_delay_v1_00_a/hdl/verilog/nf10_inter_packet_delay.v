/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        nf10_inter_packet_delay.v
 *
 *  Library:
 *        /pcores/nf10_inter_packet_delay_v1_00_a
 *
 *  Module:
 *        nf10_inter_packet_delay
 *
 *  Author:
 *        Muhammad Shahbaz
 *
 *  Description:
 *
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

`uselib lib=unisims_ver
`uselib lib=proc_common_v3_00_a

module nf10_inter_packet_delay
#(
  parameter C_S_AXI_DATA_WIDTH    = 32,
  parameter C_S_AXI_ADDR_WIDTH    = 32,
  parameter C_BASEADDR            = 32'hFFFFFFFF,
  parameter C_HIGHADDR            = 32'h00000000,
  parameter C_S_AXI_ACLK_FREQ_HZ  = 100,
  parameter C_M_AXIS_DATA_WIDTH	  = 256,
  parameter C_S_AXIS_DATA_WIDTH	  = 256,
  parameter C_M_AXIS_TUSER_WIDTH  = 128,
  parameter C_S_AXIS_TUSER_WIDTH  = 128
)
(
  // Slave AXI Ports
  input                                           S_AXI_ACLK,
  input                                           S_AXI_ARESETN,
  input      [C_S_AXI_ADDR_WIDTH-1 : 0]           S_AXI_AWADDR,
  input                                           S_AXI_AWVALID,
  input      [C_S_AXI_DATA_WIDTH-1 : 0]           S_AXI_WDATA,
  input      [C_S_AXI_DATA_WIDTH/8-1 : 0]         S_AXI_WSTRB,
  input                                           S_AXI_WVALID,
  input                                           S_AXI_BREADY,
  input      [C_S_AXI_ADDR_WIDTH-1 : 0]           S_AXI_ARADDR,
  input                                           S_AXI_ARVALID,
  input                                           S_AXI_RREADY,
  output                                          S_AXI_ARREADY,
  output     [C_S_AXI_DATA_WIDTH-1 : 0]           S_AXI_RDATA,
  output     [1 : 0]                              S_AXI_RRESP,
  output                                          S_AXI_RVALID,
  output                                          S_AXI_WREADY,
  output     [1 :0]                               S_AXI_BRESP,
  output                                          S_AXI_BVALID,
  output                                          S_AXI_AWREADY,

  // Master Stream Ports (interface to data path)
  output     [C_M_AXIS_DATA_WIDTH - 1:0]          M_AXIS_TDATA,
  output     [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0]  M_AXIS_TSTRB,
  output     [C_M_AXIS_TUSER_WIDTH-1:0]           M_AXIS_TUSER,
  output                                          M_AXIS_TVALID,
  input                                           M_AXIS_TREADY,
  output                                          M_AXIS_TLAST,

  // Slave Stream Ports (interface to RX queues)
  input      [C_S_AXIS_DATA_WIDTH - 1:0]          S_AXIS_TDATA,
  input      [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0]  S_AXIS_TSTRB,
  input      [C_S_AXIS_TUSER_WIDTH-1:0]           S_AXIS_TUSER,
  input                                           S_AXIS_TVALID,
  output                                          S_AXIS_TREADY,
  input                                           S_AXIS_TLAST
);

  // -- Internal Parameters
  localparam NUM_RW_REGS       = 4;

  // -- Signals
  wire                                            Bus2IP_Clk;
  wire                                            Bus2IP_Resetn;
  wire     [C_S_AXI_ADDR_WIDTH-1 : 0]             Bus2IP_Addr;
  wire     [0:0]                                  Bus2IP_CS;
  wire                                            Bus2IP_RNW;
  wire     [C_S_AXI_DATA_WIDTH-1 : 0]             Bus2IP_Data;
  wire     [C_S_AXI_DATA_WIDTH/8-1 : 0]           Bus2IP_BE;
  wire     [C_S_AXI_DATA_WIDTH-1 : 0]             IP2Bus_Data;
  wire                                            IP2Bus_RdAck;
  wire                                            IP2Bus_WrAck;
  wire                                            IP2Bus_Error;

  wire     [NUM_RW_REGS*C_S_AXI_DATA_WIDTH-1 : 0] rw_regs;

  wire                                            sw_rst;
  wire                                            ipd_en;
  wire                                            use_reg_val;
  wire     [C_S_AXI_DATA_WIDTH-1 : 0]             delay_reg_val;

  // -- AXILITE IPIF
  axi_lite_ipif_1bar #
  (
    .C_S_AXI_DATA_WIDTH  ( C_S_AXI_DATA_WIDTH ),
    .C_S_AXI_ADDR_WIDTH  ( C_S_AXI_ADDR_WIDTH ),
	  .C_USE_WSTRB         ( C_USE_WSTRB ),
	  .C_DPHASE_TIMEOUT    ( C_DPHASE_TIMEOUT ),
    .C_BAR0_BASEADDR     ( C_BASEADDR ),
    .C_BAR0_HIGHADDR     ( C_HIGHADDR )
  ) axi_lite_ipif_inst
  (
    .S_AXI_ACLK          ( S_AXI_ACLK     ),
    .S_AXI_ARESETN       ( S_AXI_ARESETN  ),
    .S_AXI_AWADDR        ( S_AXI_AWADDR   ),
    .S_AXI_AWVALID       ( S_AXI_AWVALID  ),
    .S_AXI_WDATA         ( S_AXI_WDATA    ),
    .S_AXI_WSTRB         ( S_AXI_WSTRB    ),
    .S_AXI_WVALID        ( S_AXI_WVALID   ),
    .S_AXI_BREADY        ( S_AXI_BREADY   ),
    .S_AXI_ARADDR        ( S_AXI_ARADDR   ),
    .S_AXI_ARVALID       ( S_AXI_ARVALID  ),
    .S_AXI_RREADY        ( S_AXI_RREADY   ),
    .S_AXI_ARREADY       ( S_AXI_ARREADY  ),
    .S_AXI_RDATA         ( S_AXI_RDATA    ),
    .S_AXI_RRESP         ( S_AXI_RRESP    ),
    .S_AXI_RVALID        ( S_AXI_RVALID   ),
    .S_AXI_WREADY        ( S_AXI_WREADY   ),
    .S_AXI_BRESP         ( S_AXI_BRESP    ),
    .S_AXI_BVALID        ( S_AXI_BVALID   ),
    .S_AXI_AWREADY       ( S_AXI_AWREADY  ),

	// Controls to the IP/IPIF modules
    .Bus2IP_Clk          ( Bus2IP_Clk     ),
    .Bus2IP_Resetn       ( Bus2IP_Resetn  ),
    .Bus2IP_Addr         ( Bus2IP_Addr    ),
    .Bus2IP_RNW          ( Bus2IP_RNW     ),
    .Bus2IP_BE           ( Bus2IP_BE      ),
    .Bus2IP_CS           ( Bus2IP_CS      ),
    .Bus2IP_Data         ( Bus2IP_Data    ),
    .IP2Bus_Data         ( IP2Bus_Data    ),
    .IP2Bus_WrAck        ( IP2Bus_WrAck   ),
    .IP2Bus_RdAck        ( IP2Bus_RdAck   ),
    .IP2Bus_Error        ( IP2Bus_Error   )
  );

  // -- IPIF REGS
  ipif_regs #
  (
    .C_S_AXI_DATA_WIDTH (C_S_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH (C_S_AXI_ADDR_WIDTH),
    .NUM_RW_REGS        (NUM_RW_REGS)
  ) ipif_regs_inst
  (
    .Bus2IP_Clk     ( Bus2IP_Clk     ),
    .Bus2IP_Resetn  ( Bus2IP_Resetn  ),
    .Bus2IP_Addr    ( Bus2IP_Addr    ),
    .Bus2IP_CS      ( Bus2IP_CS[0]   ),
    .Bus2IP_RNW     ( Bus2IP_RNW     ),
    .Bus2IP_Data    ( Bus2IP_Data    ),
    .Bus2IP_BE      ( Bus2IP_BE      ),
    .IP2Bus_Data    ( IP2Bus_Data    ),
    .IP2Bus_RdAck   ( IP2Bus_RdAck   ),
    .IP2Bus_WrAck   ( IP2Bus_WrAck   ),
    .IP2Bus_Error   ( IP2Bus_Error   ),

	  .rw_regs        ( rw_regs )
  );

  // -- Register assignments

  assign sw_rst        = rw_regs[(C_S_AXI_DATA_WIDTH*0)+0];
  assign ipd_en        = rw_regs[(C_S_AXI_DATA_WIDTH*0)+1];
  assign use_reg_val   = rw_regs[(C_S_AXI_DATA_WIDTH*0)+2];

  assign delay_reg_val = rw_regs[(C_S_AXI_DATA_WIDTH*2)-1:(C_S_AXI_DATA_WIDTH*1)];

  // -- Inter Packet Delay
  inter_packet_delay #
  (
    .C_M_AXIS_DATA_WIDTH  ( C_M_AXIS_DATA_WIDTH ),
    .C_S_AXIS_DATA_WIDTH  ( C_S_AXIS_DATA_WIDTH ),
    .C_M_AXIS_TUSER_WIDTH ( C_M_AXIS_TUSER_WIDTH ),
    .C_S_AXIS_TUSER_WIDTH ( C_S_AXIS_TUSER_WIDTH ),
    .C_S_AXI_DATA_WIDTH   ( C_S_AXI_DATA_WIDTH )
   ) inter_packet_delay
  (
    // Global Ports
    .axi_aclk             ( S_AXI_ACLK ),
    .axi_resetn           ( S_AXI_ARESETN ),

    // Master Stream Ports (interface to data path)
    .m_axis_tdata         ( M_AXIS_TDATA ),
    .m_axis_tstrb         ( M_AXIS_TSTRB ),
    .m_axis_tuser         ( M_AXIS_TUSER ),
    .m_axis_tvalid        ( M_AXIS_TVALID ),
    .m_axis_tready        ( M_AXIS_TREADY ),
    .m_axis_tlast         ( M_AXIS_TLAST ),

    // Slave Stream Ports (interface to RX queues)
    .s_axis_tdata         ( S_AXIS_TDATA ),
    .s_axis_tstrb         ( S_AXIS_TSTRB ),
    .s_axis_tuser         ( S_AXIS_TUSER ),
    .s_axis_tvalid        ( S_AXIS_TVALID ),
    .s_axis_tready        ( S_AXIS_TREADY ),
    .s_axis_tlast         ( S_AXIS_TLAST ),

    .sw_rst               ( sw_rst ),
    .ipd_en               ( ipd_en ),
    .use_reg_val          ( use_reg_val ),
    .delay_reg_val        ( delay_reg_val )
  );

endmodule
