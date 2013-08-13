/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        pcap_replay_uengine.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_pcap_replay_uengine_v1_00_a
 *
 *  Module:
 *        pcap_replay_uengine
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

module pcap_replay_uengine
#(
    //Master AXI Stream Data Width
    parameter C_M_AXIS_DATA_WIDTH  = 256,
    parameter C_S_AXIS_DATA_WIDTH  = 256,
    parameter C_M_AXIS_TUSER_WIDTH = 128,
    parameter C_S_AXIS_TUSER_WIDTH = 128,
    parameter C_S_AXI_DATA_WIDTH   = 32,
    parameter QDR_NUM_CHIPS        = 3,
    parameter QDR_DATA_WIDTH       = 36,
    parameter QDR_ADDR_WIDTH       = 19,
    parameter QDR_BW_WIDTH         = 4,
    parameter QDR_CQ_WIDTH         = 1,
    parameter QDR_CLK_WIDTH        = 1,
    parameter QDR_MASTERBANK_WIDTH = 3
)
(
    // Global Ports
    input                                      axi_aclk,
    input                                      axi_aresetn,

    input                                      qdr_clk,
    input                                      qdr_clk_200,
    input                                      qdr_clk_270,

    // Master Stream Ports (interface to data path)
    output  [C_M_AXIS_DATA_WIDTH-1:0]          m_axis_tdata,
    output  [((C_M_AXIS_DATA_WIDTH/8))-1:0]    m_axis_tstrb,
    output  [C_M_AXIS_TUSER_WIDTH-1:0]         m_axis_tuser,
    output                                     m_axis_tvalid,
    input                                      m_axis_tready,
    output                                     m_axis_tlast,

    // Slave Stream Ports (interface to RX queues)
    input [C_S_AXIS_DATA_WIDTH-1:0]            s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH/8))-1:0]      s_axis_tstrb,
    input [C_S_AXIS_TUSER_WIDTH-1:0]           s_axis_tuser,
    input                                      s_axis_tvalid,
    output                                     s_axis_tready,
    input                                      s_axis_tlast,

    // QDR Memory Interface
    input [(QDR_DATA_WIDTH)-1:0]               qdr_q_0,
    input [QDR_CQ_WIDTH-1:0]                   qdr_cq_0,
    input [QDR_CQ_WIDTH-1:0]                   qdr_cq_n_0,
    output [QDR_CLK_WIDTH-1:0]                 qdr_c_0,
    output [QDR_CLK_WIDTH-1:0]                 qdr_c_n_0,
    output                                     qdr_dll_off_n_0,
    output [QDR_CLK_WIDTH-1:0]                 qdr_k_0,
    output [QDR_CLK_WIDTH-1:0]                 qdr_k_n_0,
    output [QDR_ADDR_WIDTH-1:0]                qdr_sa_0,
    output [(QDR_BW_WIDTH)-1:0]                qdr_bw_n_0,
    output                                     qdr_w_n_0,
    output [(QDR_DATA_WIDTH)-1:0]              qdr_d_0,
    output                                     qdr_r_n_0,

    input [(QDR_DATA_WIDTH)-1:0]               qdr_q_1,
    input [QDR_CQ_WIDTH-1:0]                   qdr_cq_1,
    input [QDR_CQ_WIDTH-1:0]                   qdr_cq_n_1,
    output [QDR_CLK_WIDTH-1:0]                 qdr_c_1,
    output [QDR_CLK_WIDTH-1:0]                 qdr_c_n_1,
    output                                     qdr_dll_off_n_1,
    output [QDR_CLK_WIDTH-1:0]                 qdr_k_1,
    output [QDR_CLK_WIDTH-1:0]                 qdr_k_n_1,
    output [QDR_ADDR_WIDTH-1:0]                qdr_sa_1,
    output [(QDR_BW_WIDTH)-1:0]                qdr_bw_n_1,
    output                                     qdr_w_n_1,
    output [(QDR_DATA_WIDTH)-1:0]              qdr_d_1,
    output                                     qdr_r_n_1,

    input [(QDR_DATA_WIDTH)-1:0]               qdr_q_2,
    input [QDR_CQ_WIDTH-1:0]                   qdr_cq_2,
    input [QDR_CQ_WIDTH-1:0]                   qdr_cq_n_2,
    output [QDR_CLK_WIDTH-1:0]                 qdr_c_2,
    output [QDR_CLK_WIDTH-1:0]                 qdr_c_n_2,
    output                                     qdr_dll_off_n_2,
    output [QDR_CLK_WIDTH-1:0]                 qdr_k_2,
    output [QDR_CLK_WIDTH-1:0]                 qdr_k_n_2,
    output [QDR_ADDR_WIDTH-1:0]                qdr_sa_2,
    output [(QDR_BW_WIDTH)-1:0]                qdr_bw_n_2,
    output                                     qdr_w_n_2,
    output [(QDR_DATA_WIDTH)-1:0]              qdr_d_2,
    output                                     qdr_r_n_2,

    input [QDR_MB_WIDTH-1:0]                   qdr_masterbank_sel,

	  // Misc
    input                                      sw_rst
);

  // -- Local Functions
  function integer log2;
    input integer number;
    begin
       log2=0;
       while(2**log2<number) begin
          log2=log2+1;
       end
    end
  endfunction

  // -- Internal Parameters

  // -- Signals

  // -- Modules and Logic

  axis_to_fifo #
  (
    .C_S_AXIS_DATA_WIDTH  (C_S_AXIS_DATA_WIDTH),
    .C_S_AXIS_TUSER_WIDTH (C_S_AXIS_TUSER_WIDTH),
    .FIFO_DATA_WIDTH      ((QDR_DATA_WIDTH == 36) ? QDR_NUM_CHIPS*32 : QDR_NUM_CHIPS*64)
  )
     axis_to_fifo_inst
  (
    .axi_aclk             (axi_aclk),
    .axi_aresetn          (axi_aresetn),
    .fifo_clk             (qdr_clk),

    .s_axis_tdata         (s_axis_tdata),
    .s_axis_tstrb         (s_axis_tstrb),
    .s_axis_tuser         (s_axis_tuser),
    .s_axis_tvalid        (s_axis_tvalid),
    .s_axis_tready        (s_axis_tready),
    .s_axis_tlast         (s_axis_tlast),

    .fifo_rd_en           (),
    .fifo_dout            (),
    .fifo_dout_strb       (),
    .fifo_empty           (),
    .fifo_almost_empty    (),

    .sw_rst               (sw_rst)
  );

  fifo_to_axis #
  (
    .C_M_AXIS_DATA_WIDTH  (C_M_AXIS_DATA_WIDTH),
    .C_M_AXIS_TUSER_WIDTH (C_M_AXIS_TUSER_WIDTH),
    .FIFO_DATA_WIDTH      ((QDR_DATA_WIDTH == 36) ? QDR_NUM_CHIPS*32 : QDR_NUM_CHIPS*64)
  )
    fifo_to_axis_inst
  (

    .axi_aclk             (axi_aclk),
    .axi_aresetn          (axi_aresetn),
    .fifo_clk             (fifo_clk),

    .fifo_wr_en           (),
    .fifo_din             (),
    .fifo_din_strb        (),
    .fifo_full            (),
    .fifo_almost_full     (),


    .m_axis_tdata         (m_axis_tdata),
    .m_axis_tstrb         (m_axis_tstrb),
    .m_axis_tuser         (m_axis_tuser),
    .m_axis_tvalid        (m_axis_tvalid),
    .m_axis_tready        (m_axis_tready),
    .m_axis_tlast         (m_axis_tlast),

    .sw_rst               (sw_rst)
  );

  // ---- Primary State Machine [Combinational]


endmodule

