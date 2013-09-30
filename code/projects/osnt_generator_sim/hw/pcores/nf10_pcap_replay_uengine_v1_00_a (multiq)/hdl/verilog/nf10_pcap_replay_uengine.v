/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        nf10_pcap_replay_uengine.v
 *
 *  Library:
 *        /pcores/nf10_pcap_replay_uengine_v1_00_a
 *mem_ad_
 *        nf10_pcap_replay_uengine
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
 *        WITHOUT ANY WAC_TUSER_SRC_PORT_POSRRANTY; without even the implied warranty of
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

module nf10_pcap_replay_uengine
#(
  parameter C_S_AXI_DATA_WIDTH   = 32,
  parameter C_S_AXI_ADDR_WIDTH   = 32,
  parameter C_BASEADDR           = 32'hFFFFFFFF,
  parameter C_HIGHADDR           = 32'h00000000,
  parameter C_USE_WSTRB          = 0,
  parameter C_DPHASE_TIMEOUT     = 0,
  parameter C_S_AXI_ACLK_FREQ_HZ = 100,
  parameter C_M_AXIS_DATA_WIDTH  = 256,
  parameter C_S_AXIS_DATA_WIDTH  = 256,
  parameter C_M_AXIS_TUSER_WIDTH = 128,
  parameter C_S_AXIS_TUSER_WIDTH = 128,
	parameter C_SRC_PORT_WIDTH     = 8,
	parameter C_NUM_QUEUES         = 4,
	parameter C_TUSER_SRC_PORT_POS = 24, //16,
  parameter QDR_NUM_CHIPS        = 2,
  parameter QDR_DATA_WIDTH       = 36,
  parameter QDR_ADDR_WIDTH       = 19,
  parameter QDR_BW_WIDTH         = 4,
  parameter QDR_CQ_WIDTH         = 1,
  parameter QDR_CLK_WIDTH        = 1,
	parameter QDR_BURST_LENGTH     = 4,
	parameter QDR_CLK_PERIOD       = 4000,
  parameter SIM_ONLY             = 0
)
(
  // Clock and Reset
  input                                           axi_aclk,
  input                                           axi_aresetn,
  
  input 										  										dcm_locked,

  input                                           qdr_clk,
  input                                           qdr_clk_200,
  input                                           qdr_clk_270,

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
  input      [C_S_AXIS_DATA_WIDTH-1:0]            s_axis_tdata,
  input      [((C_S_AXIS_DATA_WIDTH/8))-1:0]      s_axis_tstrb,
  input      [C_S_AXIS_TUSER_WIDTH-1:0]           s_axis_tuser,
  input                                           s_axis_tvalid,
  output                                          s_axis_tready,
  input                                           s_axis_tlast,

  // QDR Memory Interface
  input      [(QDR_DATA_WIDTH)-1:0]               qdr_q_0,
  input      [QDR_CQ_WIDTH-1:0]                   qdr_cq_0,
  input      [QDR_CQ_WIDTH-1:0]                   qdr_cq_n_0,
  output     [QDR_CLK_WIDTH-1:0]                  qdr_c_0,
  output     [QDR_CLK_WIDTH-1:0]                  qdr_c_n_0,
  output                                          qdr_dll_off_n_0,
  output     [QDR_CLK_WIDTH-1:0]                  qdr_k_0,
  output     [QDR_CLK_WIDTH-1:0]                  qdr_k_n_0,
  output     [QDR_ADDR_WIDTH-1:0]                 qdr_sa_0,
  output     [(QDR_BW_WIDTH)-1:0]                 qdr_bw_n_0,
  output                                          qdr_w_n_0,
  output     [(QDR_DATA_WIDTH)-1:0]               qdr_d_0,
  output                                          qdr_r_n_0,
  (* S = "TRUE" *) input                          qdr_masterbank_sel_0,

  input      [(QDR_DATA_WIDTH)-1:0]               qdr_q_1,
  input      [QDR_CQ_WIDTH-1:0]                   qdr_cq_1,
  input      [QDR_CQ_WIDTH-1:0]                   qdr_cq_n_1,
  output     [QDR_CLK_WIDTH-1:0]                  qdr_c_1,
  output     [QDR_CLK_WIDTH-1:0]                  qdr_c_n_1,
  output                                          qdr_dll_off_n_1,
  output     [QDR_CLK_WIDTH-1:0]                  qdr_k_1,
  output     [QDR_CLK_WIDTH-1:0]                  qdr_k_n_1,
  output     [QDR_ADDR_WIDTH-1:0]                 qdr_sa_1,
  output     [(QDR_BW_WIDTH)-1:0]                 qdr_bw_n_1,
  output                                          qdr_w_n_1,
  output     [(QDR_DATA_WIDTH)-1:0]               qdr_d_1,
  output                                          qdr_r_n_1,
  (* S = "TRUE" *) input                          qdr_masterbank_sel_1,

  input      [(QDR_DATA_WIDTH)-1:0]               qdr_q_2,
  input      [QDR_CQ_WIDTH-1:0]                   qdr_cq_2,
  input      [QDR_CQ_WIDTH-1:0]                   qdr_cq_n_2,
  output     [QDR_CLK_WIDTH-1:0]                  qdr_c_2,
  output     [QDR_CLK_WIDTH-1:0]                  qdr_c_n_2,
  output                                          qdr_dll_off_n_2,
  output     [QDR_CLK_WIDTH-1:0]                  qdr_k_2,
  output     [QDR_CLK_WIDTH-1:0]                  qdr_k_n_2,
  output     [QDR_ADDR_WIDTH-1:0]                 qdr_sa_2,
  output     [(QDR_BW_WIDTH)-1:0]                 qdr_bw_n_2,
  output                                          qdr_w_n_2,
  output     [(QDR_DATA_WIDTH)-1:0]               qdr_d_2,
  output                                          qdr_r_n_2,
  (* S = "TRUE" *) input                          qdr_masterbank_sel_2
);

  // -- Internal Parameters
  localparam NUM_RW_REGS 					= 13;
  localparam NUM_WO_REGS 					= 0;
  localparam NUM_RO_REGS 					= 0;
	
	localparam REPLAY_COUNT_WIDTH   = 32;

  // -- Signals
  wire [NUM_RW_REGS*C_S_AXI_DATA_WIDTH-1:0]   	rw_regs;

	wire																					enable_q0;
	wire [QDR_ADDR_WIDTH-1:0]  									  mem_ad_low_q0;
	wire [QDR_ADDR_WIDTH-1:0]  										mem_ad_high_q0;
	wire [REPLAY_COUNT_WIDTH-1:0]		  						replay_count_q0;
	wire																					enable_q1;
	wire [QDR_ADDR_WIDTH-1:0]  									  mem_ad_low_q1;
	wire [QDR_ADDR_WIDTH-1:0]  										mem_ad_high_q1;
  wire [REPLAY_COUNT_WIDTH-1:0]		  						replay_count_q1;
	wire																					enable_q2;
	wire [QDR_ADDR_WIDTH-1:0]  									  mem_ad_low_q2;
	wire [QDR_ADDR_WIDTH-1:0]  										mem_ad_high_q2;
	wire [REPLAY_COUNT_WIDTH-1:0]		  						replay_count_q2;
	wire																					enable_q3;
	wire [QDR_ADDR_WIDTH-1:0]  									  mem_ad_low_q3;
	wire [QDR_ADDR_WIDTH-1:0]  										mem_ad_high_q3;
	wire [REPLAY_COUNT_WIDTH-1:0]		  						replay_count_q3;
	
  wire                                          sw_rst;

  // -- AXILITE Registers
  axi_lite_regs
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
		.rw_defaults     ({{(NUM_RW_REGS-3)*C_S_AXI_DATA_WIDTH{1'b0}}, 32'd2, 32'd8, 32'd0, 32'b11110}),
		.wo_regs         (),
		.wo_defaults     ({NUM_WO_REGS*C_S_AXI_DATA_WIDTH{1'b0}}),
		.ro_regs         ()
  );
  

  // -- Register assignments
	
  assign sw_rst     		 = rw_regs[(C_S_AXI_DATA_WIDTH*0)+0];
	assign enable_q0  		 = rw_regs[(C_S_AXI_DATA_WIDTH*0)+1];
	assign enable_q1  		 = rw_regs[(C_S_AXI_DATA_WIDTH*0)+2];
	assign enable_q2  		 = rw_regs[(C_S_AXI_DATA_WIDTH*0)+3];
	assign enable_q3  		 = rw_regs[(C_S_AXI_DATA_WIDTH*0)+4];
	
	assign mem_ad_low_q0   = rw_regs[(C_S_AXI_DATA_WIDTH*2)+QDR_ADDR_WIDTH-1:(C_S_AXI_DATA_WIDTH*1)];
	assign mem_ad_high_q0  = rw_regs[(C_S_AXI_DATA_WIDTH*3)+QDR_ADDR_WIDTH-1:(C_S_AXI_DATA_WIDTH*2)];
	assign replay_count_q0 = rw_regs[(C_S_AXI_DATA_WIDTH*4)+QDR_ADDR_WIDTH-1:(C_S_AXI_DATA_WIDTH*3)];
	assign mem_ad_low_q1   = rw_regs[(C_S_AXI_DATA_WIDTH*5)+QDR_ADDR_WIDTH-1:(C_S_AXI_DATA_WIDTH*4)];
	assign mem_ad_high_q1  = rw_regs[(C_S_AXI_DATA_WIDTH*6)+QDR_ADDR_WIDTH-1:(C_S_AXI_DATA_WIDTH*5)];
	assign replay_count_q1 = rw_regs[(C_S_AXI_DATA_WIDTH*7)+QDR_ADDR_WIDTH-1:(C_S_AXI_DATA_WIDTH*6)];
	assign mem_ad_low_q2   = rw_regs[(C_S_AXI_DATA_WIDTH*8)+QDR_ADDR_WIDTH-1:(C_S_AXI_DATA_WIDTH*7)];
	assign mem_ad_high_q2  = rw_regs[(C_S_AXI_DATA_WIDTH*9)+QDR_ADDR_WIDTH-1:(C_S_AXI_DATA_WIDTH*8)];
	assign replay_count_q2 = rw_regs[(C_S_AXI_DATA_WIDTH*10)+QDR_ADDR_WIDTH-1:(C_S_AXI_DATA_WIDTH*9)];
	assign mem_ad_low_q3   = rw_regs[(C_S_AXI_DATA_WIDTH*11)+QDR_ADDR_WIDTH-1:(C_S_AXI_DATA_WIDTH*10)];
	assign mem_ad_high_q3  = rw_regs[(C_S_AXI_DATA_WIDTH*12)+QDR_ADDR_WIDTH-1:(C_S_AXI_DATA_WIDTH*11)];
	assign replay_count_q3 = rw_regs[(C_S_AXI_DATA_WIDTH*13)+QDR_ADDR_WIDTH-1:(C_S_AXI_DATA_WIDTH*12)];
	
	// TODO: 1) add enable/disbale registers for packet replay ...
	//       2) sync the current FIFO size with Read side and loop through it ...
	//       3) no. of iteration and others etc  

  // -- Pcap Replay uEngine
  pcap_replay_uengine #
  (
    .C_M_AXIS_DATA_WIDTH  ( C_M_AXIS_DATA_WIDTH ),
    .C_S_AXIS_DATA_WIDTH  ( C_S_AXIS_DATA_WIDTH ),
    .C_M_AXIS_TUSER_WIDTH ( C_M_AXIS_TUSER_WIDTH ),
    .C_S_AXIS_TUSER_WIDTH ( C_S_AXIS_TUSER_WIDTH ),
    .C_S_AXI_DATA_WIDTH   ( C_S_AXI_DATA_WIDTH ),
		.C_SRC_PORT_WIDTH			( C_SRC_PORT_WIDTH ),
		.C_NUM_QUEUES					( C_NUM_QUEUES ),
		.C_TUSER_SRC_PORT_POS	( C_TUSER_SRC_PORT_POS ),
    .QDR_NUM_CHIPS        ( QDR_NUM_CHIPS ),
    .QDR_DATA_WIDTH       ( QDR_DATA_WIDTH ),
    .QDR_ADDR_WIDTH       ( QDR_ADDR_WIDTH ),
    .QDR_BW_WIDTH         ( QDR_BW_WIDTH ),
    .QDR_CLK_WIDTH        ( QDR_CLK_WIDTH ),
    .QDR_CQ_WIDTH         ( QDR_CQ_WIDTH ),
		.QDR_CLK_PERIOD				( QDR_CLK_PERIOD ),
		.QDR_BURST_LENGTH			( QDR_BURST_LENGTH ),
		.REPLAY_COUNT_WIDTH		( REPLAY_COUNT_WIDTH ),	
		.SIM_ONLY							( SIM_ONLY )
		
   )
     pcap_replay_uengine_inst
   (
    // Global Ports
    .axi_aclk             ( axi_aclk ),
    .axi_aresetn          ( axi_aresetn ),
	
	  .dcm_locked           ( dcm_locked ),
		
		.qdr_clk							( qdr_clk ),
		.qdr_clk_200					( qdr_clk_200 ),
		.qdr_clk_270				  ( qdr_clk_270 ),

    // Master Stream Ports (interface to data path)
	  .m_axis_tdata         ( m_axis_tdata ),
    .m_axis_tstrb         ( m_axis_tstrb ),
    .m_axis_tuser         ( m_axis_tuser ),
    .m_axis_tvalid        ( m_axis_tvalid ),
    .m_axis_tready        ( m_axis_tready ),
    .m_axis_tlast         ( m_axis_tlast ),

    // Slave Stream Ports (interface to RX queues)
    .s_axis_tdata         ( s_axis_tdata ),
    .s_axis_tstrb         ( s_axis_tstrb ),
    .s_axis_tuser         ( s_axis_tuser ),
    .s_axis_tvalid        ( s_axis_tvalid ),
    .s_axis_tready        ( s_axis_tready ),
    .s_axis_tlast         ( s_axis_tlast ),

    // QDR Memeory Interface
    .qdr_q_0              ( qdr_q_0 ),
    .qdr_cq_0             ( qdr_cq_0 ),
    .qdr_cq_n_0           ( qdr_cq_n_0 ),
    .qdr_c_0              ( qdr_c_0 ),
    .qdr_c_n_0            ( qdr_c_n_0 ),
    .qdr_dll_off_n_0      ( qdr_dll_off_n_0 ),
    .qdr_k_0              ( qdr_k_0 ),
    .qdr_k_n_0            ( qdr_k_n_0 ),
    .qdr_sa_0             ( qdr_sa_0 ),
    .qdr_bw_n_0           ( qdr_bw_n_0),
    .qdr_w_n_0            ( qdr_w_n_0 ),
    .qdr_d_0              ( qdr_d_0 ),
    .qdr_r_n_0            ( qdr_r_n_0 ),
	  .qdr_masterbank_sel_0 ( qdr_masterbank_sel_0 ),

    .qdr_q_1              ( qdr_q_1 ),
    .qdr_cq_1             ( qdr_cq_1 ),
    .qdr_cq_n_1           ( qdr_cq_n_1 ),
    .qdr_c_1              ( qdr_c_1 ),
    .qdr_c_n_1            ( qdr_c_n_1 ),
    .qdr_dll_off_n_1      ( qdr_dll_off_n_1 ),
    .qdr_k_1              ( qdr_k_1 ),
    .qdr_k_n_1            ( qdr_k_n_1 ),
    .qdr_sa_1             ( qdr_sa_1 ),
    .qdr_bw_n_1           ( qdr_bw_n_1),
    .qdr_w_n_1            ( qdr_w_n_1 ),
    .qdr_d_1              ( qdr_d_1 ),
    .qdr_r_n_1            ( qdr_r_n_1 ),
	  .qdr_masterbank_sel_1 ( qdr_masterbank_sel_1 ),

    .qdr_q_2              ( qdr_q_2 ),
    .qdr_cq_2             ( qdr_cq_2 ),
    .qdr_cq_n_2           ( qdr_cq_n_2 ),
    .qdr_c_2              ( qdr_c_2 ),
    .qdr_c_n_2            ( qdr_c_n_2 ),
    .qdr_dll_off_n_2      ( qdr_dll_off_n_2 ),
    .qdr_k_2              ( qdr_k_2 ),
    .qdr_k_n_2            ( qdr_k_n_2 ),
    .qdr_sa_2             ( qdr_sa_2 ),
    .qdr_bw_n_2           ( qdr_bw_n_2),
    .qdr_w_n_2            ( qdr_w_n_2 ),
    .qdr_d_2              ( qdr_d_2 ),
    .qdr_r_n_2            ( qdr_r_n_2 ),
	  .qdr_masterbank_sel_2 ( qdr_masterbank_sel_2 ),

    // Misc
		.enable_q0						(enable_q0),
		.mem_ad_low_q0				(mem_ad_low_q0),
		.mem_ad_high_q0				(mem_ad_high_q0),
		.replay_count_q0			(replay_count_q0),
		.enable_q1						(enable_q1),
		.mem_ad_low_q1				(mem_ad_low_q1),
		.mem_ad_high_q1				(mem_ad_high_q1),
		.replay_count_q1			(replay_count_q1),
		.enable_q2						(enable_q2),
		.mem_ad_low_q2				(mem_ad_low_q2),
		.mem_ad_high_q2				(mem_ad_high_q2),
		.replay_count_q2			(replay_count_q2),
		.enable_q3						(enable_q3),
		.mem_ad_low_q3				(mem_ad_low_q3),
		.mem_ad_high_q3				(mem_ad_high_q3),
		.replay_count_q3			(replay_count_q3),
		
    .sw_rst               ( sw_rst )
  );

endmodule
