/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        nf10_switch_output_port_lookup_tb.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_switch_output_port_lookup_v1_00_a
 *
 *  Module:
 *        testbench
 *
 *  Author:
 *        Gianni Antichi
 *
 *  Description:
 *        Testbench to verify basic functionalities of the learning CAM switch
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
    reg clk_correction;
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
				 
    localparam WAIT_CAM_INIT = 0;
    localparam HEADER_0 = 1;
    localparam HEADER_1 = 2;
    localparam PAYLOAD  = 3;
    localparam DEAD     = 4;

    localparam WAIT = 5;
    localparam REQUEST_WRITE = 6;
    localparam TUPLE0 = 7;
    localparam TUPLE1 = 8;
    localparam TUPLE2 = 9;
    localparam TUPLE3 = 10;
    localparam TUPLE4 = 11;
    localparam TUPLE5 = 12;
    localparam TUPLE6 = 13;
    localparam TUPLE7 = 14;
    localparam START_READ = 15;
    localparam READ_TUPLE0 = 16;
    localparam READ_TUPLE1 = 17;
    localparam READ_TUPLE2 = 18;
    localparam READ_TUPLE3 = 19;
    localparam READ_TUPLE4 = 20;
    localparam READ_TUPLE5 = 21;
    localparam READ_TUPLE6 = 22;
    localparam READ_TUPLE7 = 23;
    localparam READ_TUPLE8 = 53;
    localparam END = 24;
    localparam WAIT0 = 25;
    localparam WAIT1 = 26;
    localparam WAIT2 = 27;
    localparam WAIT3 = 28;
    localparam WAIT4 = 29;
    localparam WAIT5 = 30;
    localparam WAIT6 = 31;
    localparam WAIT7 = 32;
    localparam WAIT8 = 33;
    localparam WAIT9 = 34;
    localparam WAIT10 = 35;
    localparam WAIT11 = 36;
    localparam WAIT12 = 37;
    localparam WAIT13 = 38;
    localparam WAIT14 = 39;
    localparam WAIT15 = 40;
    localparam WAIT16 = 41;
    localparam WAIT17 = 42;
    localparam WAIT18 = 43;
    localparam WAIT19 = 44;
    localparam WAIT20 = 45;
    localparam WAIT21 = 46;
    localparam WAIT22 = 47;
    localparam WAIT23 = 48;
    localparam WAIT24 = 49;
    localparam WAIT25 = 50;
    localparam CUT_SET = 51;
    localparam WAIT_CUT = 52;
    localparam OFFSET = 54;
    localparam WAIT_OFF = 55;
    localparam WORD_SET = 56;
    localparam WAIT_WORD = 57;
    localparam FREEZE_STATS = 58; 
    localparam WAIT_FREEZE_COMPLETE = 59;



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
    wire [63:0]stamp_counter;
   
    reg [9:0] start,start_next;

    wire [255:0] tdata_m_arb;
    wire 	 tvalid_m_arb;
    wire	 tlast_m_arb;
    wire	 tready_m_arb;
    wire [31:0]	 tstrb_m_arb;
    wire [127:0] tuser_m_arb;

   /* wire [255:0] tdata_s_opl;
    wire         tvalid_s_opl;
    wire         tlast_s_opl;
    wire         tready_s_opl;
    wire [31:0]  tstrb_s_opl;
    wire [128:0] tuser_s_opl;*/

    wire [255:0] tdata_m_opl;
    wire         tvalid_m_opl;
    wire         tlast_m_opl;
    wire         tready_m_opl;
    wire [31:0]  tstrb_m_opl;
    wire [127:0] tuser_m_opl;

   /* wire [255:0] tdata_s_oq;
    wire         tvalid_s_oq;
    wire         tlast_s_oq;
    wire         tready_s_oq;
    wire [31:0]  tstrb_s_opl;
    wire [128:0] tuser_s_opl;*/


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
	    WAIT_CAM_INIT: begin
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
                    if(counter == 8'h1F) begin
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
            state <= WAIT_CAM_INIT;
            counter <= 8'b0;
            start <= 10'h0;
	    state_reg <= WAIT;
	    start_reg <= 10'h0;
	    //stamp_counter <= 0;
        end
        else begin
            state <= state_next;
            counter <= counter_next;
            start <= start +1;

	    //stamp_counter <= stamp_counter + 1;

            state_reg <= state_reg_next;
            //address_to_read <= address_to_read_next;
	    address_to_write<= address_to_write_next;
	    value_to_write  <= value_to_write_next;
            //request_read <= request_read_next;
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
                        state_reg_next = TUPLE0;
            end

/*            CUT_SET: begin
                request_write_next = 1;
                address_to_write_next = 32'h76800008;
                value_to_write_next = 32'h1;
                state_reg_next = WAIT_CUT;
            end

            WAIT_CUT: begin
                request_write_next = 0;
                if(write_ack)
                	state_reg_next = OFFSET;
            end

            OFFSET: begin 
                request_write_next = 1;
                address_to_write_next = 32'h7680000c;
                value_to_write_next = 32'hffffffff;
                state_reg_next = WAIT_OFF;
            end

            WAIT_OFF: begin
                request_write_next = 0;
                if(write_ack)
                        state_reg_next = WORD_SET;
            end

            WORD_SET: begin 
                request_write_next = 1;
                address_to_write_next = 32'h76800010;
                value_to_write_next = 32'h4;
                state_reg_next = WAIT_WORD;
            end

            WAIT_WORD: begin
                request_write_next = 0;
                if(write_ack)
                        state_reg_next = TUPLE0;
            end
*/

	    TUPLE0: begin //source IP
		request_write_next = 1;
                address_to_write_next = 32'h74800000;
                value_to_write_next = 32'hEFBEADDE;
                state_reg_next = WAIT1;
            end

            WAIT1: begin
                request_write_next = 0;
                //if(dwrite_ack && awrite_ack)
                if(write_ack) 
                        state_reg_next = TUPLE1;
            end


	    TUPLE1: begin //source IP mask
                request_write_next = 1;
                address_to_write_next = 32'h74800004;
                value_to_write_next = 32'hFFFFFFFF;
                state_reg_next = WAIT2;
            end

            WAIT2: begin
                request_write_next = 0;
                if(write_ack) 
                        state_reg_next = TUPLE2;
            end


            TUPLE2: begin // destination IP
                request_write_next = 1;
                address_to_write_next = 32'h74800008;
                value_to_write_next = 32'hACBACAAC;
                state_reg_next = WAIT3;
            end

            WAIT3: begin
                request_write_next = 0;
                if(write_ack) 
                        state_reg_next = TUPLE3;
            end


            TUPLE3: begin // destination IP mask
                request_write_next = 1;
                address_to_write_next = 32'h7480000c;
                value_to_write_next = 32'hFFFFFFFF;
                state_reg_next = WAIT4;
            end

            WAIT4: begin
                request_write_next = 0;
                if(write_ack) 
                        state_reg_next = TUPLE4;
            end


            TUPLE4: begin // protocol
                request_write_next = 1;
                address_to_write_next = 32'h74800018;
                value_to_write_next = 32'h11;
                state_reg_next = WAIT5;
            end

            WAIT5: begin
                request_write_next = 0;
                if(write_ack) 
                        state_reg_next = TUPLE5;
            end


            TUPLE5: begin // protocol mask
                request_write_next = 1;
                address_to_write_next = 32'h7480001c;
                value_to_write_next = 32'hFF;
                state_reg_next = WAIT6;
            end

            WAIT6: begin
                request_write_next = 0;
                if(write_ack) 
                        state_reg_next = TUPLE6;
            end


            TUPLE6: begin // l4 ports
                request_write_next = 1;
                address_to_write_next = 32'h74800010;
                value_to_write_next = 32'hEFDEACBB;
                state_reg_next = WAIT7;
            end

            WAIT7: begin
                request_write_next = 0;
                if(write_ack) 
                        state_reg_next = TUPLE7;
            end


            TUPLE7: begin // l4 ports mask
                request_write_next = 1;
                address_to_write_next = 32'h74800014;
                value_to_write_next = 32'hFFFFFFFF;
                state_reg_next = WAIT8;
            end

            WAIT8: begin
                request_write_next = 0;
                if(write_ack) 
                        state_reg_next = REQUEST_WRITE;
            end

            REQUEST_WRITE: begin // decide where to put the new entry.
                request_write_next = 1;
                address_to_write_next = 32'h74800020;
                value_to_write_next = 1;
                state_reg_next = WAIT0;
            end

            WAIT0: begin
                request_write_next = 0;
                if(write_ack)
                        state_reg_next = START_READ;
            end

            START_READ: begin // start reading the entry to see if it is stored correctly.
                request_write_next = 1;
                address_to_write_next = 32'h74800024;
                value_to_write_next = 1;
                state_reg_next = WAIT9;
            end

            WAIT9: begin
                request_write_next = 0;
                if(write_ack) 
                        state_reg_next = WAIT10;
            end


            WAIT10: begin //read source IP
		if(start_reg>15'h475) begin //let's wait some time before starting the reading operations
                	state_reg_next = READ_TUPLE0;
		end
            end

	   READ_TUPLE0: begin
		request_read = 1;
		address_to_read = 32'h74800000;
		if(read_ready)
                	state_reg_next = WAIT11;
	   end

            WAIT11: begin
		if(read_ack)
                	state_reg_next = READ_TUPLE2;
	    end

           READ_TUPLE2: begin  //read source IP mask
		if(!read_ready) begin
                	request_read = 1;
			address_to_read = 32'h74800004;
                        state_reg_next = WAIT12;
		end
           end

            WAIT12: begin 
		request_read = 1;
		address_to_read = 32'h74800004;
		if(read_ready)
                	state_reg_next = WAIT13;
            end

           WAIT13: begin
		if(read_ack)
                	state_reg_next = READ_TUPLE3;
           end


            READ_TUPLE3: begin //read destination IP
		if(!read_ready) begin
                	request_read = 1;
                	address_to_read = 32'h74800008;
                	state_reg_next = WAIT14;
		end
            end

           WAIT14: begin
                request_read = 1;
                address_to_read = 32'h74800008;
                if(read_ready) 
               		 state_reg_next = WAIT15;
           end


            WAIT15: begin
		if(read_ack)
                	state_reg_next = READ_TUPLE4;
            end

            READ_TUPLE4: begin //read destination IP mask
		if(!read_ready) begin
                	request_read = 1;
			address_to_read = 32'h7480000c;
                        state_reg_next = WAIT16;
		end
            end

            WAIT16: begin
		request_read = 1;
		address_to_read = 32'h7480000c;
		if(read_ready)
                	state_reg_next = WAIT17;
            end

            WAIT17: begin
                if(read_ack)
                        state_reg_next = READ_TUPLE5;
            end

            READ_TUPLE5: begin //read protocol
		if(!read_ready) begin
                	request_read = 1;
                	address_to_read = 32'h74800018;
                	state_reg_next = WAIT18;
		end
            end

	    WAIT18: begin 
                request_read = 1;
                address_to_read = 32'h74800018;
                if(read_ready) 
                        state_reg_next = WAIT19;
            end

            WAIT19: begin
                if(read_ack) 
                        state_reg_next = READ_TUPLE6;
            end

            READ_TUPLE6: begin //read protocol mask
                if(!read_ready) begin
                        request_read = 1;
                        address_to_read = 32'h7480001c;
                        state_reg_next = WAIT20;
                end
            end

            WAIT20: begin
                request_read = 1;
                address_to_read = 32'h7480001c;
                if(read_ready)
                        state_reg_next = WAIT21;
            end

            WAIT21: begin
                if(read_ack)
                        state_reg_next = READ_TUPLE7;
            end

            READ_TUPLE7: begin //read l4ports
                if(!read_ready) begin
                        request_read = 1;
                        address_to_read = 32'h74800010;
                        state_reg_next = WAIT22;
                end
            end

            WAIT22: begin
                request_read = 1;
                address_to_read = 32'h74800010;
                if(read_ready)
                        state_reg_next = WAIT23;
            end

            WAIT23: begin
                if(read_ack)
                        state_reg_next = READ_TUPLE8;
            end

            READ_TUPLE8: begin //read l4ports mask
                if(!read_ready) begin
                        request_read = 1;
                        address_to_read = 32'h74800014;
                        state_reg_next = WAIT24;
                end
            end

            WAIT24: begin
                request_read = 1;
                address_to_read = 32'h74800014;
                if(read_ready)
                        state_reg_next = WAIT25;
            end

            WAIT25: begin
                if(read_ack)
                        state_reg_next = FREEZE_STATS;
            end

	    FREEZE_STATS: begin
                request_write_next = 1;
                address_to_write_next = 32'h76800004;
                value_to_write_next = 32'h1;
                state_reg_next = WAIT_FREEZE_COMPLETE;
            end

            WAIT_FREEZE_COMPLETE: begin
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
      clk_correction = 1'b0;
      $display("[%t] : System Reset Asserted...", $realtime);
      reset = 1'b1;
      for (i = 0; i < 50; i = i + 1) begin
                 @(posedge clk);
      end
      $display("[%t] : System Reset De-asserted...", $realtime);
      reset = 1'b0;
  end

  always #2.5  clk = ~clk;      // 200MHz
  always #5    clk_correction = ~clk_correction;

  nf10_input_arbiter
    #(.C_M_AXIS_DATA_WIDTH(256),
      .C_S_AXIS_DATA_WIDTH(256),
      .C_M_AXIS_TUSER_WIDTH(128),
      .C_S_AXIS_TUSER_WIDTH(128)
     ) in_arb
    (
    // Global Ports
    .axi_aclk(clk),
    .axi_resetn(~reset),

    // Master Stream Ports
    .m_axis_tdata(tdata_m_arb),
    .m_axis_tstrb(tstrb_m_arb),
    .m_axis_tvalid(tvalid_m_arb),
    .m_axis_tready(tready_m_arb),
    .m_axis_tlast(tlast_m_arb),
    .m_axis_tuser(tuser_m_arb),

    // Slave Stream Ports
    .s_axis_tdata_0(tdata[0]),
    .s_axis_tuser_0(128'h0001AAAA),
    .s_axis_tstrb_0(32'hFFFFFFFF),
    .s_axis_tvalid_0(tvalid_0),
    .s_axis_tready_0(tready[0]),
    .s_axis_tlast_0(tlast[0]),

    .s_axis_tdata_1(),
    .s_axis_tuser_1(),
    .s_axis_tstrb_1(),
    .s_axis_tvalid_1(),
    .s_axis_tready_1(),
    .s_axis_tlast_1(),

    .s_axis_tdata_2(),
    .s_axis_tuser_2(),
    .s_axis_tstrb_2(),
    .s_axis_tvalid_2(),
    .s_axis_tready_2(),
    .s_axis_tlast_2(),

    .s_axis_tdata_3(),
    .s_axis_tuser_3(),
    .s_axis_tstrb_3(),
    .s_axis_tvalid_3(),
    .s_axis_tready_3(),
    .s_axis_tlast_3(),

    .s_axis_tdata_4(),
    .s_axis_tuser_4(),
    .s_axis_tstrb_4(),
    .s_axis_tvalid_4(),
    .s_axis_tready_4(),
    .s_axis_tlast_4()

   );

  nf10_monitoring_output_port_lookup
    #(.C_M_AXIS_DATA_WIDTH(256),
      .C_S_AXIS_DATA_WIDTH(256),
      .C_M_AXIS_TUSER_WIDTH(128),
      .C_S_AXIS_TUSER_WIDTH(128)
     ) opl
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

    .S_AXIS_TDATA(tdata_m_arb),
    .S_AXIS_TSTRB(tstrb_m_arb),
    .S_AXIS_TUSER(tuser_m_arb),
    .S_AXIS_TVALID(tvalid_m_arb),
    .S_AXIS_TREADY(tready_m_arb),
    .S_AXIS_TLAST(tlast_m_arb),

    .M_AXIS_TDATA(tdata_m_opl),
    .M_AXIS_TSTRB(tstrb_m_opl),
    .M_AXIS_TUSER(tuser_m_opl),
    .M_AXIS_TVALID(tvalid_m_opl),
    .M_AXIS_TREADY(tready_m_opl),
    .M_AXIS_TLAST(tlast_m_opl),

    .STAMP_COUNTER(stamp_counter)

   );


  nf10_timestamp
    #(.TIMESTAMP_WIDTH(64)
     ) timestamp
    (
    .S_AXI_ACLK(clk),
    .S_AXI_ARESETN(~reset),

    .S_AXI_AWADDR(),
    .S_AXI_AWVALID(),
    .S_AXI_WDATA(),
    .S_AXI_WSTRB(),
    .S_AXI_WVALID(),
    .S_AXI_BREADY(),
    .S_AXI_ARADDR(),
    .S_AXI_ARVALID(),
    .S_AXI_RREADY(),
    .S_AXI_ARREADY(),
    .S_AXI_RDATA(),
    .S_AXI_RRESP(),
    .S_AXI_RVALID(),
    .S_AXI_WREADY(),
    .S_AXI_BRESP(),
    .S_AXI_BVALID(),
    .S_AXI_AWREADY(),

    .CLK_CORRECTION(clk_correction),
    .STAMP_COUNTER(stamp_counter)
    );



 nf10_bram_output_queues
    #(.C_M_AXIS_DATA_WIDTH(256),
      .C_S_AXIS_DATA_WIDTH(256),
      .C_M_AXIS_TUSER_WIDTH(128),
      .C_S_AXIS_TUSER_WIDTH(128)
     ) dut
    (
    // Global Ports
    .axi_aclk(clk),
    .axi_resetn(~reset),

    // Master Stream Ports
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

     // Slave Stream Ports
    .s_axis_tdata(tdata_m_opl),
    .s_axis_tstrb(tstrb_m_opl),
    .s_axis_tvalid(tvalid_m_opl),
    .s_axis_tready(tready_m_opl),
    .s_axis_tlast(tlast_m_opl),
    .s_axis_tuser(tuser_m_opl)
   );




endmodule
