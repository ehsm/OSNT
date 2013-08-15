/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        packet_cutter.v
 *
 *  Library:
 *        hw/contrib/pcores/nf10_packet_cutter_v1_10_a
 *
 *  Module:
 *        packet_cutter
 *
 *  Author:
 *        Gianni Antichi
 *
 *  Description:
 *        Hardwire the hardware interfaces to CPU and vice versa
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


	module packet_cutter
	#(
    	//Master AXI Stream Data Width
    		parameter C_M_AXIS_DATA_WIDTH=256,
    		parameter C_S_AXIS_DATA_WIDTH=256,
    		parameter C_M_AXIS_TUSER_WIDTH=128,
    		parameter C_S_AXIS_TUSER_WIDTH=128,
		parameter C_S_AXI_DATA_WIDTH=32,
		parameter HASH_WIDTH=128
	)
	(
    	// Global Ports
    		input axi_aclk,
    		input axi_resetn,

    	// Master Stream Ports (interface to data path)
    		output reg [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
    		output reg [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tstrb,
    		output reg [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
    		output reg m_axis_tvalid,
    		input  m_axis_tready,
    		output reg m_axis_tlast,

    	// Slave Stream Ports (interface to RX queues)
    		input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
    		input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tstrb,
    		input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    		input  s_axis_tvalid,
    		output s_axis_tready,
    		input  s_axis_tlast,
 
    	// pkt cut
    		input cut_en,
    		input [C_S_AXI_DATA_WIDTH-1:0] cut_offset,
    		input [C_S_AXI_DATA_WIDTH-1:0] cut_words,
                input [C_S_AXI_DATA_WIDTH-1:0] cut_bytes
	);


   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2

	//--------------------- Internal Parameter-------------------------

   	localparam NUM_STATES               = 5;
   	localparam WAIT_PKT    		    = 1;
   	localparam IN_PACKET                = 2;
   	localparam START_HASH               = 4;
	localparam COMPLETE_PKT		    = 8;
	localparam SEND_LAST_WORD	    = 16;

   	localparam MAX_WORDS_PKT            = 2048;
	localparam HASH_BYTES		    = (HASH_WIDTH)>>3;
	localparam HASH_CARRY_WIDTH	    = log2(HASH_BYTES);     
	localparam ALL_VALID		    = 32'hffffffff; 

	//---------------------- Wires and regs---------------------------

   	reg [C_S_AXI_DATA_WIDTH-1:0]            cut_counter, cut_counter_next;
	reg [C_S_AXI_DATA_WIDTH-1:0]		tstrb_cut,tstrb_cut_next; 

   	reg [NUM_STATES-1:0]			state,state_next;

   	reg [C_M_AXIS_DATA_WIDTH-1:0]      	m_axis_tdata_next;
   	reg [((C_M_AXIS_DATA_WIDTH/8))-1:0]	m_axis_tstrb_next;
   	reg [C_M_AXIS_TUSER_WIDTH-1:0] 		m_axis_tuser_next;
   	reg 					m_axis_tvalid_next;
   	reg 					m_axis_tlast_next;

        wire [C_S_AXIS_TUSER_WIDTH-1:0]         tuser_fifo;
        wire [((C_M_AXIS_DATA_WIDTH/8))-1:0]    tstrb_fifo;
        wire                                    tlast_fifo;
        wire [C_M_AXIS_DATA_WIDTH-1:0]          tdata_fifo;

        reg                                     in_fifo_rd_en;
        wire                                    in_fifo_nearly_full;
        wire                                    in_fifo_empty;

   	wire [C_S_AXI_DATA_WIDTH-1:0]		counter;

	reg [15:0]				bytes_to_cut,bytes_to_cut_next;
	reg					pkt_short,pkt_short_next;

	wire[C_S_AXIS_DATA_WIDTH-1:0]		first_word_hash;
	wire[C_S_AXIS_DATA_WIDTH-1:0]		last_word_hash;
	wire[C_S_AXIS_DATA_WIDTH-1:0]           one_word_hash;
	wire[HASH_WIDTH-1:0]			final_hash;
	
	reg[4:0]				last_word_bytes_free;
	reg[7:0]				pkt_boundaries_bits_free;			

	reg[4:0]				bytes_free,bytes_free_next;
        reg[7:0]                                bits_free,bits_free_next;
	reg[HASH_CARRY_WIDTH-1:0]		hash_carry_bytes,hash_carry_bytes_next;
	reg[HASH_CARRY_WIDTH+2:0]		hash_carry_bits,hash_carry_bits_next;

	reg [C_S_AXIS_DATA_WIDTH-1:0]		hash;
	reg [C_S_AXIS_DATA_WIDTH-1:0]           hash_next;


   //------------------------- Modules-------------------------------


        fallthrough_small_fifo
        #(
                .WIDTH(C_M_AXIS_DATA_WIDTH+C_M_AXIS_TUSER_WIDTH+C_M_AXIS_DATA_WIDTH/8+1),
                .MAX_DEPTH_BITS(3)
        )
        pkt_fifo
        (       .din ({s_axis_tlast, s_axis_tuser, s_axis_tstrb, s_axis_tdata}),     // Data in
                .wr_en (s_axis_tvalid & ~in_fifo_nearly_full),               // Write enable
                .rd_en (in_fifo_rd_en),       // Read the next word
                .dout ({tlast_fifo, tuser_fifo, tstrb_fifo, tdata_fifo}),
                .full (),
                .prog_full (),
                .nearly_full (in_fifo_nearly_full),
                .empty (in_fifo_empty),
                .reset (~axi_resetn),
                .clk (axi_aclk));


        assign s_axis_tready = !in_fifo_nearly_full;

	assign counter = (cut_en) ? cut_words : MAX_WORDS_PKT;
	 
	assign first_word_hash = (({C_S_AXIS_DATA_WIDTH{1'b1}}<<bits_free)&tdata_fifo);
        assign last_word_hash  = (({C_S_AXIS_DATA_WIDTH{1'b1}}<<pkt_boundaries_bit_free)&tdata_fifo);
	assign one_word_hash   = (({C_S_AXIS_DATA_WIDTH{1'b1}}<<bits_free)&({C_S_AXIS_DATA_WIDTH{1'b1}}<<bits_free)&tdata_fifo);
        assign final_hash      = hash[HASH_WIDTH-1:0]^hash[(2*HASH_WIDTH)-1:HASH_WIDTH];


        always @(*) begin
                pkt_boundaries_bits_free = 0;
                case(tstrb_fifo)
                        32'b10000000_00000000_00000000_00000000:   pkt_boundaries_bits_free = 8'h248;
                        32'b11000000_00000000_00000000_00000000:   pkt_boundaries_bits_free = 8'h240;
                        32'b11100000_00000000_00000000_00000000:   pkt_boundaries_bits_free = 8'h232;
                        32'b11110000_00000000_00000000_00000000:   pkt_boundaries_bits_free = 8'h224;
                        32'b11111000_00000000_00000000_00000000:   pkt_boundaries_bits_free = 8'h216;
                        32'b11111100_00000000_00000000_00000000:   pkt_boundaries_bits_free = 8'h208;
                        32'b11111110_00000000_00000000_00000000:   pkt_boundaries_bits_free = 8'h200;
                        32'b11111111_00000000_00000000_00000000:   pkt_boundaries_bits_free = 8'h192;
                        32'b11111111_10000000_00000000_00000000:   pkt_boundaries_bits_free = 8'h184;
                        32'b11111111_11000000_00000000_00000000:   pkt_boundaries_bits_free = 8'h176;
                        32'b11111111_11100000_00000000_00000000:   pkt_boundaries_bits_free = 8'h168;
                        32'b11111111_11110000_00000000_00000000:   pkt_boundaries_bits_free = 8'h160;
                        32'b11111111_11111000_00000000_00000000:   pkt_boundaries_bits_free = 8'h152;
                        32'b11111111_11111100_00000000_00000000:   pkt_boundaries_bits_free = 8'h144;
                        32'b11111111_11111110_00000000_00000000:   pkt_boundaries_bits_free = 8'h136;
                        32'b11111111_11111111_00000000_00000000:   pkt_boundaries_bits_free = 8'h128;
                        32'b11111111_11111111_10000000_00000000:   pkt_boundaries_bits_free = 8'h120;
                        32'b11111111_11111111_11000000_00000000:   pkt_boundaries_bits_free = 8'h112;
                        32'b11111111_11111111_11100000_00000000:   pkt_boundaries_bits_free = 8'h104;
                        32'b11111111_11111111_11110000_00000000:   pkt_boundaries_bits_free = 8'h96;
                        32'b11111111_11111111_11111000_00000000:   pkt_boundaries_bits_free = 8'h88;
                        32'b11111111_11111111_11111100_00000000:   pkt_boundaries_bits_free = 8'h80;
                        32'b11111111_11111111_11111110_00000000:   pkt_boundaries_bits_free = 8'h72;
                        32'b11111111_11111111_11111111_00000000:   pkt_boundaries_bits_free = 8'h64;
                        32'b11111111_11111111_11111111_10000000:   pkt_boundaries_bits_free = 8'h56;
                        32'b11111111_11111111_11111111_11000000:   pkt_boundaries_bits_free = 8'h48;
                        32'b11111111_11111111_11111111_11100000:   pkt_boundaries_bits_free = 8'h40;
                        32'b11111111_11111111_11111111_11110000:   pkt_boundaries_bits_free = 8'h32;
                        32'b11111111_11111111_11111111_11111000:   pkt_boundaries_bits_free = 8'h24;
                        32'b11111111_11111111_11111111_11111100:   pkt_boundaries_bits_free = 8'h16;
                        32'b11111111_11111111_11111111_11111110:   pkt_boundaries_bits_free = 8'h8;
                        32'b11111111_11111111_11111111_11111111:   pkt_boundaries_bits_free = 8'h0;
                        default                                :   pkt_boundaries_bits_free = 8'h0;
                endcase
        end





        always @(*) begin
        	last_word_bytes_free = 0;
        	case(cut_offset)
                	32'b10000000_00000000_00000000_00000000:   last_word_bytes_free = 8'h31;
                        32'b11000000_00000000_00000000_00000000:   last_word_bytes_free = 8'h30;
                        32'b11100000_00000000_00000000_00000000:   last_word_bytes_free = 8'h29;
                        32'b11110000_00000000_00000000_00000000:   last_word_bytes_free = 8'h28;
                        32'b11111000_00000000_00000000_00000000:   last_word_bytes_free = 8'h27;
                        32'b11111100_00000000_00000000_00000000:   last_word_bytes_free = 8'h26;
                        32'b11111110_00000000_00000000_00000000:   last_word_bytes_free = 8'h25;
                        32'b11111111_00000000_00000000_00000000:   last_word_bytes_free = 8'h24;
                        32'b11111111_10000000_00000000_00000000:   last_word_bytes_free = 8'h23;
                        32'b11111111_11000000_00000000_00000000:   last_word_bytes_free = 8'h22;
                        32'b11111111_11100000_00000000_00000000:   last_word_bytes_free = 8'h21;
                        32'b11111111_11110000_00000000_00000000:   last_word_bytes_free = 8'h20;
                        32'b11111111_11111000_00000000_00000000:   last_word_bytes_free = 8'h19;
                        32'b11111111_11111100_00000000_00000000:   last_word_bytes_free = 8'h18;
                        32'b11111111_11111110_00000000_00000000:   last_word_bytes_free = 8'h17;
                        32'b11111111_11111111_00000000_00000000:   last_word_bytes_free = 8'h16;
                        32'b11111111_11111111_10000000_00000000:   last_word_bytes_free = 8'h15;
                        32'b11111111_11111111_11000000_00000000:   last_word_bytes_free = 8'h14;
                        32'b11111111_11111111_11100000_00000000:   last_word_bytes_free = 8'h13;
                        32'b11111111_11111111_11110000_00000000:   last_word_bytes_free = 8'h12;
                        32'b11111111_11111111_11111000_00000000:   last_word_bytes_free = 8'h11;
                        32'b11111111_11111111_11111100_00000000:   last_word_bytes_free = 8'h10;
                        32'b11111111_11111111_11111110_00000000:   last_word_bytes_free = 8'h9;
                        32'b11111111_11111111_11111111_00000000:   last_word_bytes_free = 8'h8;
                        32'b11111111_11111111_11111111_10000000:   last_word_bytes_free = 8'h7;
                        32'b11111111_11111111_11111111_11000000:   last_word_bytes_free = 8'h6;
                        32'b11111111_11111111_11111111_11100000:   last_word_bytes_free = 8'h5;
                        32'b11111111_11111111_11111111_11110000:   last_word_bytes_free = 8'h4;
                        32'b11111111_11111111_11111111_11111000:   last_word_bytes_free = 8'h3;
                        32'b11111111_11111111_11111111_11111100:   last_word_bytes_free = 8'h2;
                        32'b11111111_11111111_11111111_11111110:   last_word_bytes_free = 8'h1;
                        32'b11111111_11111111_11111111_11111111:   last_word_bytes_free = 8'h0;
                	default				       :   last_word_bytes_free = 8'h0;
        	endcase
   	end

	always @(*) begin
      		m_axis_tuser_next = tuser_fifo;
      		m_axis_tstrb_next = tstrb_fifo;
      		m_axis_tlast_next = tlast_fifo;
      		m_axis_tdata_next = tdata_fifo;
      		m_axis_tvalid_next = 0;
   
      		in_fifo_rd_en = 0;
      
		state_next = state;
      		
		cut_counter_next = cut_counter;
		tstrb_cut_next = tstrb_cut;

		bytes_free_next = bytes_free;
		bits_free_next = bits_free;
		hash_carry_bytes_next = hash_carry_bytes;
                hash_carry_bits_next = hash_carry_bits;

		bytes_to_cut_next = bytes_to_cut;
		pkt_short_next = 0;

		hash_next = hash;

      	case(state)
        
	WAIT_PKT: begin
                cut_counter_next = counter;
                tstrb_cut_next = cut_offset;
        	if(!in_fifo_empty) begin
                	m_axis_tvalid_next = 1;
			if(cut_bytes > tuser_fifo[15:0])
				pkt_short_next = 1;
			else
				bytes_to_cut_next = tuser_fifo[15:0]-cut_bytes;
			bytes_free_next = last_word_bytes_free;
			bits_free_next = (last_word_bytes_free<<3);
			if(m_axis_tready) begin
				in_fifo_rd_en = 1;
				state_next = IN_PACKET;
			end
           	end
        end

        IN_PACKET: begin
        	if(!in_fifo_empty) begin
			if(!cut_counter) begin
				if(tlast_fifo) begin
					if(pkt_short) begin
						m_axis_tvalid_next = 1;
						if(m_axis_tready) begin
							in_fifo_rd_en = 1;
                                                	state_next = WAIT_PKT;
						end
					end
					else begin
						if(bytes_to_cut<HASH_WIDTH) begin
							m_axis_tvalid_next = 1;
							if(m_axis_tready) begin
								in_fifo_rd_en = 1;
								state_next = WAIT_PKT;
							end
						end
						else begin 
							hash_next = one_word_hash;
							state_next = COMPLETE_PKT;
						end
					end
				end
				else begin
					hash_next = first_word_hash;
					in_fifo_rd_en = 1;
					state_next = START_HASH;	
				end
			end
			else begin
				m_axis_tvalid_next = 1;
				if(m_axis_tready) begin
					in_fifo_rd_en = 1;
					if(tlast_fifo)
						state_next = WAIT_PKT;
					else
						cut_counter_next = cut_counter-1;
				end
			end
		end
	end

	
	START_HASH: begin
		if(tlast_fifo) begin 
			hash_next = hash ^ last_word_hash;
			state_next = COMPLETE_PKT;
		end
		else begin
			if(!in_fifo_empty) begin
				in_fifo_rd_en = 1;
				hash_next = hash ^ tdata_fifo;
			end
		end
	end

	COMPLETE_PKT: begin
		m_axis_tvalid_next = 1;
		if(m_axis_tready) begin
			in_fifo_rd_en = 1;
			if(bytes_free < HASH_BYTES) begin
				m_axis_tlast_next = 0;
				//m_axis_tdata_next[bits_free-1:0] = final_hash[HASH_WIDTH-1:HASH_WIDTH-bits_free];
				m_axis_tdata_next = (tdata_fifo & tstrb_cut) | (final_hash >> (HASH_WIDTH-bits_free));
				m_axis_tstrb_next = ALL_VALID;
				hash_carry_bytes_next = HASH_BYTES - bytes_free;
				hash_carry_bits_next = (HASH_BYTES - bytes_free)<<3;
				state_next = SEND_LAST_WORD;
			end
			else begin
				m_axis_tlast_next = 1;
				//m_axis_tdata_next[bits_free-1:bits_free-HASH_WIDTH] = final_hash;
				m_axis_tdata_next = (tdata_fifo & tstrb_cut) | (final_hash << (bits_free-HASH_WIDTH));
				m_axis_tstrb = (ALL_VALID<<(bytes_free-HASH_BYTES));
				state_next = WAIT_PKT;
			end
		end
	end
	
	SEND_LAST_WORD: begin
		m_axis_tvalid_next = 1;
		if(m_axis_tready) begin
			m_axis_tlast_next = 1;
			//m_axis_tdata_next = final_hash[HASH_WIDTH-bits_free-1:0]<<(C_M_AXIS_DATA_WIDTH-hash_carry_bits);
			m_axis_tdata_next = final_hash<<(C_M_AXIS_DATA_WIDTH-hash_carry_bits);
			m_axis_tstrb_next = (ALL_VALID<<(32-hash_carry_bytes));
			state_next = WAIT_PKT;
		end
	end

	endcase // case(state)
	end // always @ (*)


	always @(posedge axi_aclk) begin
      		if(~axi_resetn) begin
         		state 		<= WAIT_PKT;
         		cut_counter	<= 0;
			tstrb_cut	<= 0;
         		m_axis_tvalid   <= 0;
         		m_axis_tdata    <= 0;
         		m_axis_tuser    <= 0;
         		m_axis_tstrb    <= 0;
         		m_axis_tlast    <= 0;
                        bytes_free 	<= 0;
                        bits_free 	<= 0;
			bytes_to_cut    <= 0;
                        hash_carry_bytes<= 0;
                        hash_carry_bits <= 0;
                        hash 		<= 0;
			pkt_short       <= 0;
      		end
      		else begin
         		state <= state_next;

	 		m_axis_tvalid<= m_axis_tvalid_next;
         		m_axis_tdata <= m_axis_tdata_next;
         		m_axis_tuser <= m_axis_tuser_next;
         		m_axis_tstrb <= m_axis_tstrb_next;
         		m_axis_tlast <= m_axis_tlast_next;

                	bytes_free <= bytes_free_next;
                	bits_free <= bits_free_next;
                	hash_carry_bytes <= hash_carry_bytes_next;
                	hash_carry_bits <= hash_carry_bits_next;

			bytes_to_cut <= bytes_to_cut_next;
			pkt_short    <= pkt_short_next;

                	hash <= hash_next;
			
         		cut_counter <= cut_counter_next;
			tstrb_cut <= tstrb_cut_next;
      		end
   	end
	endmodule // output_port_lookup

