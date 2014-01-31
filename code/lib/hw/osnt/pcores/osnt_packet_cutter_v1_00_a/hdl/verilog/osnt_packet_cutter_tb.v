/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        osnt_packet_cutter_tb.v
 *
 *  Library:
 *        hw/osnt/pcores/osnt_packet_cutter_v1_00_a
 *
 *  Module:
 *        testbench
 *
 *  Author:
 *        Gianni Antichi
 *
 *  Description:
 *        Testbench to verify basic functionalities of the packet cutter
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
module testbench();

    reg clk, reset;
    reg [255:0]  tdata[4:0];
    reg [4:0]  tlast;
    wire[4:0]  tready;

   reg 	       tvalid_0 = 0;
   reg 	       tvalid_1 = 0;
   reg 	       tvalid_2 = 0;
   reg 	       tvalid_3 = 0;
   reg 	       tvalid_4 = 0;

    reg [3:0] random = 0;

    integer i;

    wire [255:0] header_word_0 = 256'h AAAAAAAAAAAAAAAAAAAAAAAA080045AAAAAAAAAAAAAAAA11AAAAEFBEADDEACBA; // PROTO + SRC IP + DST_IP_LO
    wire [255:0] header_word_1 = 256'h CAACACBBEFDEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA; // DST_IP_HI + L4 PORTS
				 
    localparam WAIT_TIME = 0;
    localparam HEADER_0 = 1;
    localparam HEADER_1 = 2;
    localparam PAYLOAD  = 3;
    localparam DEAD     = 4;

    localparam WAIT = 5;
    localparam WORD_SET = 6;
    localparam WAIT_WORD = 7;
    localparam OFFSET = 8;
    localparam WAIT_OFF = 9;
    localparam BYTES_SET = 10;
    localparam WAIT_BYTES = 11;
    localparam CUT_SET = 12;
    localparam WAIT_CUT = 13;
    localparam END = 14;

    wire [255:0] tdata_m_cut;
    wire         tvalid_m_cut;
    wire         tlast_m_cut;
    wire [31:0]  tstrb_m_cut;
    wire [127:0] tuser_m_cut;

    reg       request_read = 0;
    reg       request_read_next = 0;
    reg       request_write=0;
    reg       request_write_next=0;

    reg [31:0]address_to_read=0;
    reg [31:0]address_to_read_next=0;
    reg [31:0]address_to_write=0;
    reg [31:0]address_to_write_next=0;

    reg [31:0]value_read;
    reg [31:0]value_to_write;
    reg [31:0]value_to_write_next;

    wire       read_ack;
    wire       read_ready;
    wire       awrite_ack;
    wire       dwrite_ack;
    wire       write_ack;

    reg [6:0] state_reg, state_reg_next;
    reg [14:0] start_reg;

    reg [3:0] state, state_next;
    reg [7:0] counter, counter_next;
   
    reg [9:0] start,start_next;

    always @(*) begin
       state_next = state;
       tdata[0] = 256'b0;
       tdata[1] = 256'b0;
       tdata[2] = 256'b0;
       tdata[3] = 256'b0;
       tdata[4] = 256'b0;
       tlast[0] = 1'b0;
       tlast[1] = 1'b0;
       tlast[2] = 1'b0;
       tlast[3] = 1'b0;
       tlast[4] = 1'b0;
       counter_next = counter;

        case(state)
	    WAIT_TIME: begin
                if(start>10'h600)
			state_next = HEADER_0;
            end

            HEADER_0: begin
                tdata[random] = header_word_0;
                if(tready[random]) begin
                    state_next = HEADER_1;
                end
	       if (random == 0)
		 tvalid_0 = 1;
	       else if (random == 1)
		 tvalid_1 = 1;
	       else if (random == 2)
		 tvalid_2 = 1;
	       else if (random == 3)
		 tvalid_3 = 1;
	       else if (random == 4)
		 tvalid_4 = 1;
            end
            HEADER_1: begin
                tdata[random] = header_word_1;
                if(tready[random]) begin
                    state_next = PAYLOAD;
                end
            end
            PAYLOAD: begin
                tdata[random] = {32{counter}};
                if(tready[random]) begin
                    counter_next = counter + 1'b1;
                    if(counter == 8'h1) begin
                        state_next = DEAD;
                        counter_next = 8'b0;
                        tlast[random] = 1'b1;
                    end
                end
            end

            DEAD: begin

                counter_next = counter + 1'b1;
                tlast[random] = 1'b0;
         	tvalid_0 = 0;
	        tvalid_1 = 0;
		tvalid_2 = 0;
		tvalid_3 = 0;
		tvalid_4 = 0;
                if(counter[7]==1'b1) begin
                   counter_next = 8'b0;
		   random = 0;
                   state_next = HEADER_0;
                end
            end
        endcase
    end

    always @(posedge clk) begin
        if(reset) begin
            state <= WAIT_TIME;
            counter <= 8'b0;
            start <= 10'h0;
	    state_reg <= WAIT;
	    start_reg <= 10'h0;
        end
        else begin
            state <= state_next;
            counter <= counter_next;
            start <= start +1;

            state_reg <= state_reg_next;
	    address_to_write<= address_to_write_next;
	    value_to_write  <= value_to_write_next;
	    request_write<= request_write_next;
            start_reg <= start_reg +1;

        end
    end

  always @(*) begin
       state_reg_next = state_reg;
       address_to_read = 0;
       address_to_write_next= address_to_write;
       value_to_write_next  = value_to_write;
       request_write_next = 0;
       request_read  = 0;

        case(state_reg)
            WAIT: begin
                if(start_reg>15'h400)
                        state_reg_next = WORD_SET;
            end

            WORD_SET: begin
                request_write_next = 1;
                address_to_write_next = 32'h77800004;
                value_to_write_next = 32'h0;
                state_reg_next = WAIT_WORD;
            end

            WAIT_WORD: begin
                request_write_next = 0;
                if(write_ack)
                	state_reg_next = OFFSET;
            end

            OFFSET: begin 
                request_write_next = 1;
                address_to_write_next = 32'h77800008;
                value_to_write_next = 32'hfffffffe;
                state_reg_next = WAIT_OFF;
            end

            WAIT_OFF: begin
                request_write_next = 0;
                if(write_ack)
                        state_reg_next = BYTES_SET;
            end

            BYTES_SET: begin 
                request_write_next = 1;
                address_to_write_next = 32'h7780000c;
                value_to_write_next = 32'h3f; //63 Bytes
                state_reg_next = WAIT_BYTES;
            end

            WAIT_BYTES: begin
                request_write_next = 0;
                if(write_ack)
                        state_reg_next = CUT_SET;
            end

            CUT_SET: begin
                request_write_next = 1;
                address_to_write_next = 32'h77800000;
                value_to_write_next = 32'h1;
                state_reg_next = WAIT_CUT;
            end

            WAIT_CUT: begin
                request_write_next = 0;
                if(write_ack)
                        state_reg_next = END;
            end

	   END: begin //stop accessing registers: loop
	   end
	endcase
     end


  initial begin
      clk   = 1'b0;

      $display("[%t] : System Reset Asserted...", $realtime);
      reset = 1'b1;
      for (i = 0; i < 50; i = i + 1) begin
                 @(posedge clk);
      end
      $display("[%t] : System Reset De-asserted...", $realtime);
      reset = 1'b0;
  end

  always #2.5  clk = ~clk;      // 200MHz


  osnt_packet_cutter
    #(.C_M_AXIS_DATA_WIDTH(256),
      .C_S_AXIS_DATA_WIDTH(256),
      .C_M_AXIS_TUSER_WIDTH(128),
      .C_S_AXIS_TUSER_WIDTH(128),
      .HASH_WIDTH(128)
     ) cutter
    (
    // Global Ports
    .S_AXI_ACLK(clk),
    .S_AXI_ARESETN(~reset),

    // control path
    .S_AXI_AWADDR(address_to_write),
    .S_AXI_AWVALID(request_write),
    .S_AXI_WDATA(value_to_write),
    .S_AXI_WSTRB(4'hF),
    .S_AXI_WVALID(request_write),
    .S_AXI_BREADY(1'b1),
    .S_AXI_ARADDR(address_to_read),
    .S_AXI_ARVALID(request_read),
    .S_AXI_RREADY(1'b1),
    .S_AXI_ARREADY(read_ready), //read_ack
    .S_AXI_RDATA(),
    .S_AXI_RRESP(),
    .S_AXI_RVALID(read_ack),
    .S_AXI_WREADY(dwrite_ack),
    .S_AXI_BRESP(),
    .S_AXI_BVALID(write_ack),
    .S_AXI_AWREADY(awrite_ack),

    // data path

    .S_AXIS_TDATA(tdata[0]),
    .S_AXIS_TSTRB(32'hFFFFFFFF),
    .S_AXIS_TUSER(128'h02010080),
    .S_AXIS_TVALID(tvalid_0),
    .S_AXIS_TREADY(tready[0]),
    .S_AXIS_TLAST(tlast[0]),

    .M_AXIS_TDATA(tdata_m_cut),
    .M_AXIS_TSTRB(tstrb_m_cut),
    .M_AXIS_TUSER(tuser_m_cut),
    .M_AXIS_TVALID(tvalid_m_cut),
    .M_AXIS_TREADY(tready_m_cut),
    .M_AXIS_TLAST(tlast_m_cut)

   );


 nf10_bram_output_queues
    #(.C_M_AXIS_DATA_WIDTH(256),
      .C_S_AXIS_DATA_WIDTH(256),
      .C_M_AXIS_TUSER_WIDTH(128),
      .C_S_AXIS_TUSER_WIDTH(128)
     ) dut
    (
    .axi_aclk(clk),
    .axi_resetn(~reset),

    .m_axis_tdata_0(),
    .m_axis_tstrb_0(),
    .m_axis_tvalid_0(),
    .m_axis_tready_0(1'b1),
    .m_axis_tlast_0(),
    .m_axis_tuser_0(),

    .m_axis_tdata_1(),
    .m_axis_tstrb_1(),
    .m_axis_tvalid_1(),
    .m_axis_tready_1(1'b1),
    .m_axis_tlast_1(),
    .m_axis_tuser_1(),

    .m_axis_tdata_2(),
    .m_axis_tstrb_2(),
    .m_axis_tvalid_2(),
    .m_axis_tready_2(1'b1),
    .m_axis_tlast_2(),
    .m_axis_tuser_2(),

    .m_axis_tdata_3(),
    .m_axis_tstrb_3(),
    .m_axis_tvalid_3(),
    .m_axis_tready_3(1'b1),
    .m_axis_tlast_3(),
    .m_axis_tuser_3(),

    .m_axis_tdata_4(),
    .m_axis_tstrb_4(),
    .m_axis_tvalid_4(),
    .m_axis_tready_4(1'b1),
    .m_axis_tlast_4(),
    .m_axis_tuser_4(),

    .s_axis_tdata(tdata_m_cut),
    .s_axis_tstrb(tstrb_m_cut),
    .s_axis_tvalid(tvalid_m_cut),
    .s_axis_tready(tready_m_cut),
    .s_axis_tlast(tlast_m_cut),
    .s_axis_tuser(tuser_m_cut)
   );



endmodule
