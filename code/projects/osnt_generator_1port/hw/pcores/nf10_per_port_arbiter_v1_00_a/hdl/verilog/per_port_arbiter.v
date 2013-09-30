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
  parameter C_M_AXIS_DATA_WIDTH   = 256,
  parameter C_S_AXIS_DATA_WIDTH   = 256,
  parameter C_M_AXIS_TUSER_WIDTH  = 128,
  parameter C_S_AXIS_TUSER_WIDTH  = 128,
  parameter C_S_NUM_QUEUES        = 5,
	parameter C_TUSER_TIMESTAMP_POS = 32,
	parameter TIMESTAMP_WIDTH       = 32
)
(
    // Global Ports
    input                                                     axi_aclk,
    input                                                     axi_aresetn,
                                                              
    // Master Stream Ports (interface to data path)           
    output reg [C_M_AXIS_DATA_WIDTH-1:0]                      m_axis_tdata,
    output reg [((C_M_AXIS_DATA_WIDTH/8))-1:0]                m_axis_tstrb,
    output reg [C_M_AXIS_TUSER_WIDTH-1:0]                     m_axis_tuser,
    output reg                                                m_axis_tvalid,
    input                                                     m_axis_tready,
    output reg                                                m_axis_tlast,

    // Slave Stream Ports (interface to RX queues)
    input      [C_S_NUM_QUEUES*C_S_AXIS_DATA_WIDTH-1:0]       s_axis_tdata_grp,
    input      [(C_S_NUM_QUEUES*(C_S_AXIS_DATA_WIDTH/8))-1:0] s_axis_tstrb_grp,
    input      [C_S_NUM_QUEUES*C_S_AXIS_TUSER_WIDTH-1:0]      s_axis_tuser_grp,
    input      [C_S_NUM_QUEUES-1:0]                           s_axis_tvalid_grp,
    output     [C_S_NUM_QUEUES-1:0]                           s_axis_tready_grp,
    input      [C_S_NUM_QUEUES-1:0]                           s_axis_tlast_grp,

	  // Misc
    input                                                     sw_rst
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
  parameter IN_PKT_HEADER = 0;
  parameter IN_PKT_BODY   = 1;

  // -- Signals
  genvar                                     i;
  integer									 									 j;
  
  reg                               		 		 state;
  reg                               		 		 next_state;

  reg   [0:C_S_NUM_QUEUES-1]                 in_fifo_rd_en;
  wire  [0:C_S_NUM_QUEUES-1]                 in_fifo_wr_en;
  wire  [0:C_S_NUM_QUEUES-1]                 in_fifo_nearly_full;
  wire  [0:C_S_NUM_QUEUES-1]                 in_fifo_empty;
  wire  [C_M_AXIS_DATA_WIDTH-1:0]            in_fifo_tdata [0:C_S_NUM_QUEUES-1];
  wire  [C_M_AXIS_TUSER_WIDTH-1:0]           in_fifo_tuser [0:C_S_NUM_QUEUES-1];
  wire  [C_M_AXIS_DATA_WIDTH/8-1:0]          in_fifo_tstrb [0:C_S_NUM_QUEUES-1];
  wire  [0:C_S_NUM_QUEUES-1]                 in_fifo_tlast;

  wire  [C_S_AXIS_DATA_WIDTH-1:0]            s_axis_tdata [0:C_S_NUM_QUEUES-1];
  wire  [((C_S_AXIS_DATA_WIDTH/8))-1:0]      s_axis_tstrb [0:C_S_NUM_QUEUES-1];
  wire  [C_S_AXIS_TUSER_WIDTH-1:0]           s_axis_tuser [0:C_S_NUM_QUEUES-1];
  wire  [0:C_S_NUM_QUEUES-1]                 s_axis_tvalid;
  wire  [0:C_S_NUM_QUEUES-1]                 s_axis_tready;
  wire  [0:C_S_NUM_QUEUES-1]                 s_axis_tlast;
	
  wire  [C_S_AXIS_DATA_WIDTH-1:0]            m_axis_tdata_c;
  wire  [((C_S_AXIS_DATA_WIDTH/8))-1:0]      m_axis_tstrb_c;
  wire  [C_S_AXIS_TUSER_WIDTH-1:0]           m_axis_tuser_c;

	wire  [TIMESTAMP_WIDTH:0]               	 arrival_time [0:C_S_NUM_QUEUES-1];

  wire  [log2(C_S_NUM_QUEUES)-1:0]           cmp_if;
  reg   [log2(C_S_NUM_QUEUES)-1:0]           cmp_if_c;
  reg   [log2(C_S_NUM_QUEUES)-1:0]           cmp_if_r;

  // -- Unpack AXI Slave Interface
  generate
    for (i=0; i<C_S_NUM_QUEUES; i=i+1) begin: _unpack_s_axis
      assign s_axis_tdata[i]      = s_axis_tdata_grp[C_S_AXIS_DATA_WIDTH*(i+1)-1:C_S_AXIS_DATA_WIDTH*i];
      assign s_axis_tstrb[i]      = s_axis_tstrb_grp[(C_S_AXIS_DATA_WIDTH/8)*(i+1)-1:(C_S_AXIS_DATA_WIDTH/8)*i];
      assign s_axis_tuser[i]      = s_axis_tuser_grp[C_S_AXIS_TUSER_WIDTH*(i+1)-1:C_S_AXIS_TUSER_WIDTH*i];
      assign s_axis_tvalid[i]     = s_axis_tvalid_grp[i];
      assign s_axis_tready_grp[i] = s_axis_tready[i];
      assign s_axis_tlast[i]      = s_axis_tlast_grp[i];
    end
  endgenerate

  // -- Modules and Logic
  generate
    for (i=0; i<C_S_NUM_QUEUES; i=i+1) begin : _input_fifo_grp
      fallthrough_small_fifo #(.WIDTH(C_S_AXIS_DATA_WIDTH+C_S_AXIS_TUSER_WIDTH+C_S_AXIS_DATA_WIDTH/8+1), .MAX_DEPTH_BITS(2))
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

      assign arrival_time[i] = {in_fifo_empty[i], in_fifo_tuser[i][C_TUSER_TIMESTAMP_POS+TIMESTAMP_WIDTH-1:C_TUSER_TIMESTAMP_POS]}; 
	                                              // Concatenating with fifo_empty signal to make the arrival time
                                                // large incase the given fifo is empty, to avoid garbage comparison.
    end
  endgenerate

  // --- Priority Arbiter
  generate
    for (i=0; i<C_S_NUM_QUEUES; i=i+1) begin: _arbiter
      reg [TIMESTAMP_WIDTH:0] cmp_arrival_time = {(TIMESTAMP_WIDTH+1){1'b0}};
      reg [log2(C_S_NUM_QUEUES)-1:0] cmp_if = 0;
		  wire [TIMESTAMP_WIDTH:0] arrival_time_c = arrival_time[i];

      if (i==0) begin : _0
        always @ * begin
          cmp_arrival_time = arrival_time_c;
          cmp_if = i;
        end
      end
      else begin : _n
        always @ * begin
          if (_arbiter[i-1].cmp_arrival_time < arrival_time_c) begin
            cmp_arrival_time = _arbiter[i-1].cmp_arrival_time;
            cmp_if = _arbiter[i-1].cmp_if;
          end
          else begin
            cmp_arrival_time = arrival_time_c;
            cmp_if = i;
          end
        end
      end
    end
  endgenerate

  assign cmp_if = _arbiter[C_S_NUM_QUEUES-1].cmp_if;
  
	assign m_axis_tdata_c = in_fifo_tdata[cmp_if_c];
	assign m_axis_tstrb_c = in_fifo_tstrb[cmp_if_c];
	assign m_axis_tuser_c = in_fifo_tuser[cmp_if_c];
	
  // --- Primary State Machine [Combinational]
  always @ * begin
    next_state = state;

		for (j=0; j<C_S_NUM_QUEUES; j=j+1)
    	in_fifo_rd_en[j] = 0;
		
		m_axis_tdata  = m_axis_tdata_c;
		m_axis_tstrb  = m_axis_tstrb_c;
		m_axis_tuser  = m_axis_tuser_c;
		m_axis_tvalid = 0;
		m_axis_tlast  = 0;
	
		cmp_if_c = cmp_if_r;
	
    case (state)
      IN_PKT_HEADER: begin
        if (!in_fifo_empty[cmp_if]) begin
          m_axis_tvalid = 1;
		  		cmp_if_c = cmp_if;

          if (m_axis_tready) begin
            in_fifo_rd_en[cmp_if] = 1;

            if (!in_fifo_tlast[cmp_if])
              next_state = IN_PKT_BODY;
						else
		      		m_axis_tlast = 1;
          end
        end
      end
		
      IN_PKT_BODY: begin
        if (!in_fifo_empty[cmp_if_c]) begin
          m_axis_tvalid = 1;

          if (m_axis_tready) begin
            in_fifo_rd_en[cmp_if_c] = 1;

            if (in_fifo_tlast[cmp_if_c]) begin
			  			m_axis_tlast = 1;
              next_state = IN_PKT_HEADER;
						end
          end
        end
      end
    endcase
  end

  // --- Primary State Machine [Sequential]
  always @ (posedge axi_aclk) begin
    if(!axi_aresetn || sw_rst) begin
      state     <= IN_PKT_HEADER;
      cmp_if_r  <= 0;
    end
    else begin
      state     <= next_state;
      cmp_if_r  <= cmp_if_c;
    end
  end

endmodule

