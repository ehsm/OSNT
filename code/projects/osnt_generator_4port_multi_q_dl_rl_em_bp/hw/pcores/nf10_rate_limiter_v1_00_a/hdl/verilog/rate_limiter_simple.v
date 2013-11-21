/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        rate_limiter.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_rate_limiter_v1_00_a
 *
 *  Module:
 *        rate_limiter_simple
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

 /* Consideriations:
  * In this module we are not following the standard leaky bucket model --- where the rate at which the packet is read from the bucket is controlled ---
  * instead we are controlling the rate at which the packets are written into the bucket i.e., to get a 1G avg. rate using the 10G MAC you will send
  * a packet (e.g. 8 words) once and will wait for 9 * packet size before sending the next packet. Also, if rate limiting enabled, it will provide a rate
  * of 10G/2, 10G/4, 10G/8 and so on ...
  */

module rate_limiter
#(
    //Master AXI Stream Data Width
    parameter C_M_AXIS_DATA_WIDTH  = 256,
    parameter C_S_AXIS_DATA_WIDTH  = 256,
    parameter C_M_AXIS_TUSER_WIDTH = 128,
    parameter C_S_AXIS_TUSER_WIDTH = 128,
    parameter C_S_AXI_DATA_WIDTH   = 32
)
(
    // Global Ports
    input                                      axi_aclk,
    input                                      axi_aresetn,

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

	// Misc
    input                                      sw_rst,
    input                                      rate_lim_en,
    input [C_S_AXI_DATA_WIDTH-1:0]             rate_in_bits
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
  parameter WAIT_FOR_PKT  = 0;
  parameter WAIT_FOR_IPG  = 1; // IPG - Inter Packet Gap

  // -- Signals
  reg                               state;
  reg                               next_state;

  reg                               in_fifo_rd_en;
  reg                               in_fifo_wr_en;
  wire                              in_fifo_nearly_full;
  wire                              in_fifo_empty;
  wire  [C_M_AXIS_DATA_WIDTH-1:0]   in_fifo_tdata;
  wire  [C_M_AXIS_TUSER_WIDTH-1:0]  in_fifo_tuser;
  wire  [C_M_AXIS_DATA_WIDTH/8-1:0] in_fifo_tstrb;
  wire                              in_fifo_tlast;

  reg   [63:0]                      timer_ticks;
  reg   [63:0]                      next_timer_ticks;


  // -- Modules and Logic

  fallthrough_small_fifo #(.WIDTH(1+C_S_AXIS_TUSER_WIDTH+(C_S_AXIS_DATA_WIDTH/8)+C_S_AXIS_DATA_WIDTH), .MAX_DEPTH_BITS(2))
    input_fifo
      ( .din         ({s_axis_tlast, s_axis_tuser, s_axis_tstrb, s_axis_tdata}),
        .wr_en       (in_fifo_wr_en),
        .rd_en       (in_fifo_rd_en),
        .dout        ({in_fifo_tlast, in_fifo_tuser, in_fifo_tstrb, in_fifo_tdata}),
        .full        (),
        .prog_full   (),
        .nearly_full (in_fifo_nearly_full),
        .empty       (in_fifo_empty),
        .reset       (!axi_aresetn || sw_rst),
        .clk         (axi_aclk)
      );


  // ---- Primary State Machine [Combinational]
  always @ * begin
    next_state = state;

    in_fifo_rd_en = 0;
    in_fifo_wr_en = 0;

    next_timer_ticks = timer_ticks;

    m_axis_tdata  = {C_M_AXIS_DATA_WIDTH{1'b0}};
    m_axis_tstrb  = {C_M_AXIS_DATA_WIDTH/8{1'b0}};
    m_axis_tuser  = {C_M_AXIS_TUSER_WIDTH{1'b0}};
    m_axis_tvalid = 0;
    s_axis_tready = 0;
    m_axis_tlast  = 0;

    if (!rate_lim_en) begin
	  	m_axis_tdata  = s_axis_tdata;
      m_axis_tstrb  = s_axis_tstrb;
      m_axis_tuser  = s_axis_tuser;
      m_axis_tvalid = s_axis_tvalid;
      s_axis_tready = m_axis_tready;
      m_axis_tlast  = s_axis_tlast;
    end
    else begin
      s_axis_tready = !in_fifo_nearly_full;
      in_fifo_wr_en = s_axis_tready && s_axis_tvalid;
	  
	    m_axis_tdata  = in_fifo_tdata;
      m_axis_tstrb  = in_fifo_tstrb;
      m_axis_tuser  = in_fifo_tuser;

      case (state)
        WAIT_FOR_PKT: begin
          if (!in_fifo_empty) begin
            m_axis_tvalid = 1;

            if (m_axis_tready) begin
              in_fifo_rd_en = 1;

              if (in_fifo_tlast) begin
			    			m_axis_tlast     = 1;
                next_timer_ticks = (timer_ticks + 1) << rate_in_bits;
                next_state       = WAIT_FOR_IPG;
              end
              else begin
                next_timer_ticks = timer_ticks + 1;
              end
            end
          end
        end
		
        WAIT_FOR_IPG: begin
          if (timer_ticks > 1) begin
            next_timer_ticks = timer_ticks - 1;
          end
          else begin
            next_timer_ticks = 0;
            next_state       = WAIT_FOR_PKT;
          end
        end
      endcase
    end
  end

  // ---- Primary State Machine [Sequential]
  always @ (posedge axi_aclk) begin
    if(!axi_aresetn || sw_rst) begin
      state       <= WAIT_FOR_PKT;
	  	timer_ticks <= {64{1'b0}};
    end
    else begin
      state       <= next_state;
      timer_ticks <= next_timer_ticks;
    end
  end

endmodule

