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
    parameter QDR_MB_WIDTH         = 3
)
(
    // Global Ports
    input                                      axi_aclk,
    input                                      axi_aresetn,

    input                                      qdr_clk,
    input                                      qdr_clk_200,
    input                                      qdr_clk_270,

    // Master Stream Ports (interface to data path)
    output reg [C_M_AXIS_DATA_WIDTH-1:0]       m_axis_tdata,
    output reg [((C_M_AXIS_DATA_WIDTH/8))-1:0] m_axis_tstrb,
    output reg [C_M_AXIS_TUSER_WIDTH-1:0]      m_axis_tuser,
    output reg                                 m_axis_tvalid,
    input                                      m_axis_tready,
    output reg                                 m_axis_tlast,

    // Slave Stream Ports (interface to RX queues)
    input [C_S_AXIS_DATA_WIDTH-1:0]            s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH/8))-1:0]      s_axis_tstrb,
    input [C_S_AXIS_TUSER_WIDTH-1:0]           s_axis_tuser,
    input                                      s_axis_tvalid,
    output reg                                 s_axis_tready,
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

    input [QDR_MB_WIDTH-1:0]                   qdr_mb_sel,

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

  wire                      qdr_reset;

  // -- Modules and Logic

  AxiToFifo #(
    .TDATA_WIDTH         (TDATA_WIDTH),
    .CROPPED_TDATA_WIDTH (CROPPED_TDATA_WIDTH),
    .TUSER_WIDTH         (TUSER_WIDTH),
    .TID_WIDTH           (TID_WIDTH),
    .TDEST_WIDTH         (TDEST_WIDTH),
    .NUM_QUEUES          (NUM_QUEUES),
    .QUEUE_ID_WIDTH      (QUEUE_ID_WIDTH)
  )
    axi2fifo_inst
  (
    .clk                 (axi_aclk),
    .reset               (!axi_aresetn),
    .tvalid              (s_axis_tvalid),
    .tready              (s_axis_tready),
    .tdata               (s_axis_tdata),
    .tstrb               (s_axis_tstrb),
    .tlast               (s_axis_tlast),
    .tuser               (s_axis_tuser),
    .tid                 (),
    .tdest               (),
    .memclk              (qdr_clk),
    .memreset            (qdr_reset),
    .r_inc               (r_inc_in),
    .r_empty             (r_empty_in),
    .r_almost_empty      (r_almost_empty_in),
    .dout_valid          (dout_valid_in),
    .dout                (dout_in[(8*CROPPED_TDATA_WIDTH+9)-1:0]),
    .cal_done            (&cal_done),
    .output_inc          (output_inc),
    .input_fifo_cnt      (input_fifo_cnt[31:0])
  );

  FifoToAxi #(
    .TDATA_WIDTH         (TDATA_WIDTH),
    .CROPPED_TDATA_WIDTH (CROPPED_TDATA_WIDTH),
    .TUSER_WIDTH         (TUSER_WIDTH),
    .TID_WIDTH           (TID_WIDTH),
    .TDEST_WIDTH         (TDEST_WIDTH),
    .NUM_QUEUES          (NUM_QUEUES),
    .QUEUE_ID_WIDTH      (QUEUE_ID_WIDTH)
  )
    fifo2axi_inst
  (
    .clk                 (axi_aclk),
    .reset               (!axi_aresetn),
    .tvalid              (m_axis_tvalid),
    .tready              (m_axis_tready),
    .tdata               (m_axis_tdata),
    .tstrb               (m_axis_tstrb),
    .tlast               (m_axis_tlast),
    .tuser               (m_axis_tuser),
    .tid                 (),
    .tdest               (),
    .memclk              (qdr_clk),
    .memreset            (qdr_reset),
    .r_inc               (r_inc_out),
    .w_full              (w_full_out),
    .w_almost_full       (w_almost_full_out),
    .din_valid           (din_valid_out),
    .din                 (din_out[(8*CROPPED_TDATA_WIDTH+9)-1:0]),
    .cal_done            (&cal_done),
    .output_fifo_cnt     (output_fifo_cnt[31:0])
  );




  // ---- Primary State Machine [Combinational]


endmodule

