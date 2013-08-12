/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        nf10_per_port_arbiter.v
 *
 *  Library:
 *        /pcores/nf10_per_port_arbiter_v1_00_a
 *
 *  Module:
 *        nf10_per_port_arbiter
 *
 *  Author:
 *        Muhammad Shahbaz
 *
 *  Description:
 *        Limits the rate at which packets pass through.
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

module nf10_rate_limiter
#(
  parameter C_S_AXI_DATA_WIDTH    = 32,
  parameter C_S_AXI_ADDR_WIDTH    = 32,
  parameter C_BASEADDR            = 32'hFFFFFFFF,
  parameter C_HIGHADDR            = 32'h00000000,
  parameter C_USE_WSTRB           = 0,
  parameter C_DPHASE_TIMEOUT      = 0,
  parameter C_S_AXI_ACLK_FREQ_HZ  = 100,
  parameter C_M_AXIS_DATA_WIDTH	  = 256,
  parameter C_S_AXIS_DATA_WIDTH	  = 256,
  parameter C_M_AXIS_TUSER_WIDTH  = 128,
  parameter C_M_AXIS_TUSER_WIDTH  = 128,
  parameter C_S_NUM_QUEUES      = 5
)
(
  // Clock and Reset
  input                                           axi_aclk,
  input                                           axi_aresetn,

  // Slave AXI Ports
  input      [C_S_AXI_ADDR_WIDTH-1:0]             s_axi_awaddr,
  input                                           s_axi_awvalid,
  input      [C_S_AXI_DATA_WIDTH-1:0]             s_axi_wdata,
  input      [C_S_AXI_DATA_WIDTH/8-1:0]           s_axi_wstrb,
  input                                           s_axi_wvalid,
  input                                           s_axi_bready,
  input      [C_S_AXI_ADDR_WIDTH-1:0]             s_axi_araddr,
  input                                           s_axi_arvalid,
  input                                           s_axi_rready,
  output                                          s_axi_arready,
  output     [C_S_AXI_DATA_WIDTH-1:0]             s_axi_rdata,
  output     [1:0]                                s_axi_rresp,
  output                                          s_axi_rvalid,
  output                                          s_axi_wready,
  output     [1:0]                                s_axi_bresp,
  output                                          s_axi_bvalid,
  output                                          s_axi_awready,

  // Master Stream Ports (interface to data path)
  output     [C_M_AXIS_DATA_WIDTH-1:0]            m_axis_tdata,
  output     [((C_M_AXIS_DATA_WIDTH/8))-1:0]      m_axis_tstrb,
  output     [C_M_AXIS_TUSER_WIDTH-1:0]           m_axis_tuser,
  output                                          m_axis_tvalid,
  input                                           m_axis_tready,
  output                                          m_axis_tlast,

  // Slave Stream Ports (interface to RX queues)
  input      [C_S_AXIS_DATA_WIDTH-1:0]            s_axis_tdata_0,
  input      [((C_S_AXIS_DATA_WIDTH/8))-1:0]      s_axis_tstrb_0,
  input      [C_S_AXIS_TUSER_WIDTH-1:0]           s_axis_tuser_0,
  input                                           s_axis_tvalid_0,
  output                                          s_axis_tready_0,
  input                                           s_axis_tlast_0,

  input      [C_S_AXIS_DATA_WIDTH-1:0]            s_axis_tdata_1,
  input      [((C_S_AXIS_DATA_WIDTH/8))-1:0]      s_axis_tstrb_1,
  input      [C_S_AXIS_TUSER_WIDTH-1:0]           s_axis_tuser_1,
  input                                           s_axis_tvalid_1,
  output                                          s_axis_tready_1,
  input                                           s_axis_tlast_1,

  input      [C_S_AXIS_DATA_WIDTH-1:0]            s_axis_tdata_2,
  input      [((C_S_AXIS_DATA_WIDTH/8))-1:0]      s_axis_tstrb_2,
  input      [C_S_AXIS_TUSER_WIDTH-1:0]           s_axis_tuser_2,
  input                                           s_axis_tvalid_2,
  output                                          s_axis_tready_2,
  input                                           s_axis_tlast_2,

  input      [C_S_AXIS_DATA_WIDTH-1:0]            s_axis_tdata_3,
  input      [((C_S_AXIS_DATA_WIDTH/8))-1:0]      s_axis_tstrb_3,
  input      [C_S_AXIS_TUSER_WIDTH-1:0]           s_axis_tuser_3,
  input                                           s_axis_tvalid_3,
  output                                          s_axis_tready_3,
  input                                           s_axis_tlast_3,

  input      [C_S_AXIS_DATA_WIDTH-1:0]            s_axis_tdata_4,
  input      [((C_S_AXIS_DATA_WIDTH/8))-1:0]      s_axis_tstrb_4,
  input      [C_S_AXIS_TUSER_WIDTH-1:0]           s_axis_tuser_4,
  input                                           s_axis_tvalid_4,
  output                                          s_axis_tready_4,
  input                                           s_axis_tlast_4
);

  // -- Internal Parameters
  localparam NUM_RW_REGS       = 2;

  // -- Signals
  wire     [NUM_RW_REGS*C_S_AXI_DATA_WIDTH-1 : 0] rw_regs;
  wire                                            sw_rst;

  wire     [C_S_NUM_QUEUES-1:0]                 s_axis_tready_c;

  // -- AXILITE REGs
  axi_lite_regs_1bar
  #(
    .C_S_AXI_DATA_WIDTH   (C_S_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH   (C_S_AXI_ADDR_WIDTH),
    .C_USE_WSTRB          (C_USE_WSTRB),
    .C_DPHASE_TIMEOUT     (C_DPHASE_TIMEOUT),
    .C_BAR0_BASEADDR      (C_BASEADDR),
    .C_BAR0_HIGHADDR      (C_HIGHADDR),
    .C_S_AXI_ACLK_FREQ_HZ (C_S_AXI_ACLK_FREQ_HZ),
    .NUM_RW_REGS          (NUM_RW_REGS),
    .NUM_WO_REGS          (NUM_WO_REGS),
    .NUM_RO_REGS          (NUM_RO_REGS)
  )
    axi_lite_regs_1bar_inst
  (
    .s_axi_aclk      (axi_aclk),
    .s_axi_aresetn   (axi_aresetn),
    .s_axi_awaddr    (s_axi_awaddr),
    .s_axi_awvalid   (s_axi_awvalid),
    .s_axi_wdata     (s_axi_wdata),
    .s_axi_wstrb     (s_axi_wstrb),
    .s_axi_wvalid    (s_axi_wvalid),
    .s_axi_bready    (s_axi_bready),
    .s_axi_araddr    (s_axi_araddr),
    .s_axi_arvalid   (s_axi_arvalid),
    .s_axi_rready    (s_axi_rready),
    .s_axi_arready   (s_axi_arready),
    .s_axi_rdata     (s_axi_rdata),
    .s_axi_rresp     (s_axi_rresp),
    .s_axi_rvalid    (s_axi_rvalid),
    .s_axi_wready    (s_axi_wready),
    .s_axi_bresp     (s_axi_bresp),
    .s_axi_bvalid    (s_axi_bvalid),
    .s_axi_awready   (s_axi_awready),

    .rw_regs         (rw_regs),
  );

  // -- Register assignments

  assign sw_rst        = rw_regs[(C_S_AXI_DATA_WIDTH*0)+0];

  // -- Inter Packet Delay
  per_port_arbiter #
  (
    .C_M_AXIS_DATA_WIDTH  ( C_M_AXIS_DATA_WIDTH ),
    .C_S_AXIS_DATA_WIDTH  ( C_S_AXIS_DATA_WIDTH ),
    .C_m_axis_tuser_WIDTH ( C_M_AXIS_TUSER_WIDTH ),
    .C_m_axis_tuser_WIDTH ( C_M_AXIS_TUSER_WIDTH ),
    .C_S_AXI_DATA_WIDTH   ( C_S_AXI_DATA_WIDTH ),
    .C_S_NUM_QUEUES       ( C_S_NUM_QUEUES )
  )
    per_port_arbiter
  (
    // Global Ports
    .axi_aclk           ( axi_aclk ),
    .axi_aresetn        ( axi_aresetn ),

    // Master Stream Ports (interface to data path)
    .m_axis_tdata       ( m_axis_tdata ),
    .m_axis_tstrb       ( m_axis_tstrb ),
    .m_axis_tuser       ( m_axis_tuser ),
    .m_axis_tvalid      ( m_axis_tvalid ),
    .m_axis_tready      ( m_axis_tready ),
    .m_axis_tlast       ( m_axis_tlast ),

    // Slave Stream Ports (interface to RX queues)
    .s_axis_tdata_grp   ( {s_axis_tdata_4,
                           s_axis_tdata_3,
                           s_axis_tdata_2,
                           s_axis_tdata_1,
                           s_axis_tdata_0} ),
    .s_axis_tstrb_grp   ( {s_axis_tstrb_4,
                           s_axis_tstrb_3,
                           s_axis_tstrb_2,
                           s_axis_tstrb_1,
                           s_axis_tstrb_0} ),
    .s_axis_tuser_grp   ( {s_axis_tuser_4,
                           s_axis_tuser_3,
                           s_axis_tuser_2,
                           s_axis_tuser_1,
                           s_axis_tuser_0} ),
    .s_axis_tvalid_grp  ( {s_axis_tvalid_4,
                           s_axis_tvalid_3,
                           s_axis_tvalid_2,
                           s_axis_tvalid_1,
                           s_axis_tvalid_0} ),
    .s_axis_tready_grp  ( s_axis_tready_c ),
    .s_axis_tlast_grp   ( {s_axis_tlast_4,
                           s_axis_tlast_3,
                           s_axis_tlast_2,
                           s_axis_tlast_1,
                           s_axis_tlast_0} ),

    .sw_rst               ( sw_rst )
  );

  assign {s_axis_tready_4,
          s_axis_tready_3,
          s_axis_tready_2,
          s_axis_tready_1,
          s_axis_tready_0} = s_axis_tready_c;

endmodule
