/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        extract_metadata.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_extract_metadata_v1_00_a
 *
 *  Module:
 *        extract_metadata
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
 *        MERCHANTABILITY or FITNESS FOR A PARTICULAqR PURPOSE.  See the GNU
 *        Lesser General Public License for more details.
 *
 *        You should have received a copy of the GNU Lesser General Public
 *        License along with the NetFPGA source package.  If not, see
 *        http://www.gnu.org/licenses/.
 *
 */

module extract_metadata
#(
    //Master AXI Stream Data Width
    parameter C_M_AXIS_DATA_WIDTH   = 256,
    parameter C_S_AXIS_DATA_WIDTH   = 256,
    parameter C_M_AXIS_TUSER_WIDTH  = 128,
    parameter C_S_AXIS_TUSER_WIDTH  = 128,
    parameter C_S_AXI_DATA_WIDTH    = 32,
		parameter C_TUSER_TIMESTAMP_POS = 32,
		parameter SIM_ONLY              = 0
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
    input [C_S_AXIS_DATA_WIDTH-1:0]            			s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH/8))-1:0]      			s_axis_tstrb,
    input [C_S_AXIS_TUSER_WIDTH-1:0]           			s_axis_tuser,
    input                                      			s_axis_tvalid,
    output reg                                 			s_axis_tready,
    input                                      			s_axis_tlast,
                                                  	
		// Misc
		input																						em_enable,
		
    input                                      			sw_rst
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
  localparam RD_TUSER_BITS = 0;
  localparam RD_PKT_BITS   = 1;
	
  // -- Signals
	genvar																		i;
	
  reg                                       state;
  reg                                       next_state;
	
  reg    [31:0]         										timestamp_c;
  reg    [31:0]         										timestamp_r;
	
  reg                                       fifo_rd_en;
  reg                                       fifo_wr_en;
  wire                                      fifo_nearly_full;
  wire                                      fifo_empty;
  wire  [C_S_AXIS_DATA_WIDTH-1:0]           fifo_tdata;
  wire  [C_S_AXIS_TUSER_WIDTH-1:0]          fifo_tuser;
  wire  [C_S_AXIS_DATA_WIDTH/8-1:0]         fifo_tstrb;
  wire                                      fifo_tlast;
	
  // -- Modules and Logic
  fallthrough_small_fifo #(.WIDTH(C_S_AXIS_DATA_WIDTH+C_S_AXIS_TUSER_WIDTH+C_S_AXIS_DATA_WIDTH/8+1), .MAX_DEPTH_BITS(2))
    input_fifo_inst
      ( .din         ({s_axis_tlast, s_axis_tuser, s_axis_tstrb, s_axis_tdata}),
        .wr_en       (fifo_wr_en),
        .rd_en       (fifo_rd_en),
        .dout        ({fifo_tlast, fifo_tuser, fifo_tstrb, fifo_tdata}),
        .full        (),
        .prog_full   (),
        .nearly_full (fifo_nearly_full),
        .empty       (fifo_empty),
        .reset       (!axi_aresetn || sw_rst),
        .clk         (axi_aclk)
      );
  
  // ---- AXI (Side) State Machine [Combinational]
  always @ * begin
    next_state = state;
		
		fifo_wr_en = 0;
		fifo_rd_en = 0;
		
    timestamp_c = timestamp_r;
		
    m_axis_tdata  = {C_M_AXIS_DATA_WIDTH{1'b0}};
    m_axis_tstrb  = {C_M_AXIS_DATA_WIDTH/8{1'b0}};
    m_axis_tuser  = {C_M_AXIS_TUSER_WIDTH{1'b0}};
    m_axis_tvalid = 0;
    s_axis_tready = 0;
    m_axis_tlast  = 0;
		
    if (!em_enable) begin
	  	m_axis_tdata  = s_axis_tdata;
      m_axis_tstrb  = s_axis_tstrb;
      m_axis_tuser  = s_axis_tuser;
      m_axis_tvalid = s_axis_tvalid;
      s_axis_tready = m_axis_tready;
      m_axis_tlast  = s_axis_tlast;
    end
    else begin
    	s_axis_tready = !fifo_nearly_full;
    	fifo_wr_en = s_axis_tready && s_axis_tvalid;
    
    	m_axis_tdata = fifo_tdata;
    	m_axis_tstrb = fifo_tstrb;
    	m_axis_tuser = fifo_tuser;
			m_axis_tuser[C_TUSER_TIMESTAMP_POS+32-1:C_TUSER_TIMESTAMP_POS] = timestamp_r;

    	case (state)
      	RD_TUSER_BITS: begin
        	if (!fifo_empty) begin 
          	timestamp_c = fifo_tdata[31:0]; 
          	fifo_rd_en = 1;

          	next_state = RD_PKT_BITS;
        	end
      	end
			
     	 	RD_PKT_BITS: begin
        	if (!fifo_empty) begin
          	m_axis_tvalid = 1;

          	if (m_axis_tready) begin
            	fifo_rd_en = 1;
							timestamp_c = 32'd0; 

            	if (fifo_tlast) begin
              	m_axis_tlast = 1;
              	next_state = RD_TUSER_BITS;
            	end
          	end
        	end
      	end
    	endcase
		end
  end

  // ---- Primary State Machine [Sequential]
  always @ (posedge axi_aclk) begin
    if(!axi_aresetn || sw_rst) begin
      state <= RD_TUSER_BITS;
      timestamp_r <= 32'b0;
    end
    else begin
      state <= next_state;
      timestamp_r <= timestamp_c;
    end
  end

endmodule

