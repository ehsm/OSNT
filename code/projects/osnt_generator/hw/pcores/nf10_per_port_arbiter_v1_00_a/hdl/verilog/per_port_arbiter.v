/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        per_port_arbiter.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_per_port_arbiter_v1_00_a
 *
 *  Module:
 *        per_port_arbiter
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

module per_port_arbiter
#(
    //Master AXI Stream Data Width
    parameter C_M_AXIS_DATA_WIDTH  = 256,
    parameter C_S_AXIS_DATA_WIDTH  = 256,
    parameter C_M_AXIS_TUSER_WIDTH = 128,
    parameter C_S_AXIS_TUSER_WIDTH = 128,
    parameter C_S_AXI_DATA_WIDTH   = 32,
    parameter C_S_NUM_INPUT_IF     = 5
)
(
    // Global Ports
    input                                           axi_aclk,
    input                                           axi_aresetn,

    // Master Stream Ports (interface to data path)
    output reg [C_M_AXIS_DATA_WIDTH-1:0]            m_axis_tdata,
    output reg [((C_M_AXIS_DATA_WIDTH/8))-1:0]      m_axis_tstrb,
    output reg [C_M_AXIS_TUSER_WIDTH-1:0]           m_axis_tuser,
    output reg                                      m_axis_tvalid,
    input                                           m_axis_tready,
    output reg                                      m_axis_tlast,

    // Slave Stream Ports (interface to RX queues)
    input      [C_S_NUM_INPUT_IF*C_S_AXIS_DATA_WIDTH-1:0]          s_axis_tdata_grp,
    input      [(C_S_NUM_INPUT_IF*(C_S_AXIS_DATA_WIDTH/8))-1:0]    s_axis_tstrb_grp,
    input      [C_S_NUM_INPUT_IF*C_S_AXIS_TUSER_WIDTH-1:0]         s_axis_tuser_grp,
    input      [C_S_NUM_INPUT_IF-1:0]                              s_axis_tvalid_grp,
    output     [C_S_NUM_INPUT_IF-1:0]                              s_axis_tready_grp,
    input      [C_S_NUM_INPUT_IF-1:0]                              s_axis_tlast_grp,

	  // Misc
    input                                           sw_rst
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

  // -- Signals
  genvar                                     i;

  reg                                        in_fifo_rd_en [0:C_S_NUM_INPUT_IF-1];
  reg                                        in_fifo_wr_en [0:C_S_NUM_INPUT_IF-1];
  wire                                       in_fifo_nearly_full [0:C_S_NUM_INPUT_IF-1];
  wire                                       in_fifo_empty [0:C_S_NUM_INPUT_IF-1];
  wire  [C_M_AXIS_DATA_WIDTH-1:0]            in_fifo_tdata [0:C_S_NUM_INPUT_IF-1];
  wire  [C_M_AXIS_TUSER_WIDTH-1:0]           in_fifo_tuser [0:C_S_NUM_INPUT_IF-1];
  wire  [C_M_AXIS_DATA_WIDTH/8-1:0]          in_fifo_tstrb [0:C_S_NUM_INPUT_IF-1];
  wire                                       in_fifo_tlast [0:C_S_NUM_INPUT_IF-1];

  wire  [C_S_AXIS_DATA_WIDTH-1:0]            s_axis_tdata [0:C_S_NUM_INPUT_IF-1];
  wire  [((C_S_AXIS_DATA_WIDTH/8))-1:0]      s_axis_tstrb [0:C_S_NUM_INPUT_IF-1];
  wire  [C_S_AXIS_TUSER_WIDTH-1:0]           s_axis_tuser [0:C_S_NUM_INPUT_IF-1];
  wire                                       s_axis_tvalid [0:C_S_NUM_INPUT_IF-1];
  wire                                       s_axis_tready [0:C_S_NUM_INPUT_IF-1];
  wire                                       s_axis_tlast [0:C_S_NUM_INPUT_IF-1];

  wire  [+1:]                                arrival_time [0:C_S_NUM_INPUT_IF-1];

  wire  [log2(C_S_NUM_INPUT_IF)-1:0]         cmp_if;

  // -- Unpack AXI Slave Interface
  generate
    for (i=0; i<C_S_NUM_INPUT_IF; i=i+1) begin: unpack_s_axis
      s_axis_tdata[i] = s_axis_tdata_grp[C_S_AXIS_DATA_WIDTH*(i+1)-1:C_S_AXIS_DATA_WIDTH*i];
      s_axis_tstrb[i] = s_axis_tstrb_grp[(C_S_AXIS_DATA_WIDTH/8)*(i+1)-1:(C_S_AXIS_DATA_WIDTH/8)*i];
      s_axis_tuser[i] = s_axis_tuser_grp[C_S_AXIS_TUSER_WIDTH*(i+1)-1:C_S_AXIS_TUSER_WIDTH*i];
      s_axis_tvalid[i] = s_axis_tvalid_grp[i];
      s_axis_tready_grp[i] = s_axis_tready[i];
      s_axis_tlast[i] = s_axis_tlast_grp[i];
    end
  endgenerate


  // -- Modules and Logic
  generate
    for (i=0; i<C_S_NUM_INPUT_IF; i=i+1) begin : input_fifo_grp
      fallthrough_small_fifo #(.WIDTH(C_M_AXIS_DATA_WIDTH+C_M_AXIS_TUSER_WIDTH+C_M_AXIS_DATA_WIDTH/8+1), .MAX_DEPTH_BITS(2))
        _inst
          ( .din         ({s_axis_tlast[i], s_axis_tuser[i], s_axis_tstrb[i], s_axis_tdata[i]}),
            .wr_en       (in_fifo_wr_en[i]),
            .rd_en       (in_fifo_rd_en[i]),
            .dout        ({in_fifo_tlast[i], in_fifo_tuser[i], in_fifo_tstrb[i], in_fifo_tdata[i]}),
            .full        (),
            .prog_full   (),
            .nearly_full (in_fifo_nearly_full[i]),
            .empty       (in_fifo_empty[i]),
            .reset       (!axi_aresetn || sw_rst),
            .clk         (axi_aclk)
          );

      assign s_axis_tready[i] = !in_fifo_nearly_full[i];
      assign in_fifo_wr_en[i] = s_axis_tvalid[i] && s_axis_tready[i];

      assign arrival_time[i] = {in_fifo_empty[i], in_fifo_tuser[i][:]}; // Concatenating with fifo_empty signal to make the arrival time
                                                                        // large incase the given fifo is empty, to avoid garbage comparison.
    end
  endgenerate

  // --- Priority Arbiter
  generate
    for (i=0; i<C_S_NUM_INPUT_IF; i=i+1) begin: _arbiter
      reg [32:0] cmp_arrival_time = 33'b0;
      reg [log2(C_S_NUM_INPUT_IF)-1:0] cmp_if = 0;

      if (i==0) begin : _0
        always @ * begin
          cmp_arrival_time = arrival_time[i];
          cmp_if = i-1;
        end
      end
      else begin : _n
        always @ * begin
          if (_arbiter[i-1].cmp_arrival_time < arrival_time[i]) begin
            cmp_arrival_time = _arbiter[i-1].cmp_arrival_time;
            cmp_if = _arbiter[i-1].cmp_if;
          end
          else begin
            cmp_arrival_time = arrival_time[i];
            cmp_if = i;
          end
        end
      end
    end
  endgenerate

  assign cmp_if = _arbiter[C_S_NUM_INPUT_IF-1].cmp_if;

  // ---- Primary State Machine [Combinational]
  always @ * begin
    in_fifo_rd_en = {C_S_NUM_INPUT_IF{1'b0}};
    in_fifo_rd_en[cmp_if] = m_axis_tvalid && m_axis_tready;

    m_axis_tdata = in_fifo_tdata[cmp_if];
    m_axis_tstrb = in_fifo_tstrb[cmp_if];
    m_axis_tuser = in_fifo_tuser[cmp_if];
    m_axis_tvalid = !in_fifo_empty[cmp_if];
    m_axis_tlast = in_fifo_tlast[cmp_if];
  end

endmodule

