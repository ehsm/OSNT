/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        rx_ctrl.v
 *
 *  Module:
 *        dma
 *
 *  Author:
 *        Yilong Geng
 *        Mario Flajslik
 *
 *  Description:
 *        This module controls the reception of packets from the AXIS interface.
 *        It also manages RX descriptors on the card, sending completion
 *        notifications and interrupts, as well as realignment of data on the
 *        AXIS interface, if neccessary.
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

`include "dma_defs.vh"

module rx_ctrl
  (
   input logic [63:0]                 host_rx_dne_head,
   input logic [63:0]                 mem_rx_pkt_head,
   
   // memory write interfaces
   output logic [`MEM_ADDR_BITS-1:0]  mem_rx_pkt_wr_addr,
   output logic [63:0]                mem_rx_pkt_wr_data,
   output logic [7:0]                 mem_rx_pkt_wr_mask,
   output logic                       mem_rx_pkt_wr_en,

   output logic [`MEM_ADDR_BITS-1:0]  mem_rx_dne_wr_addr,
   output logic [63:0]                mem_rx_dne_wr_data,
   output logic [7:0]                 mem_rx_dne_wr_mask,
   output logic                       mem_rx_dne_wr_en,

   output logic [`MEM_ADDR_BITS-12:0] mem_vld_rx_dne_wr_addr,
   output logic [31:0]                mem_vld_rx_dne_wr_mask,
   output logic                       mem_vld_rx_dne_wr_clear,
   input logic                        mem_vld_rx_dne_wr_stall,
   output logic [`MEM_ADDR_BITS-12:0] mem_vld_rx_dne_rd_addr,
   input logic [31:0]                 mem_vld_rx_dne_rd_bits,

   output logic [`MEM_ADDR_BITS-12:0] mem_vld_tx_dne_rd_addr,
   input logic [31:0]                 mem_vld_tx_dne_rd_bits,

   // Config registers
   //input logic [63:0]                 rx_dsc_mask,
   input logic [63:0]                 rx_pkt_mask,
   input logic [63:0]                 tx_dne_mask,
   input logic [63:0]                 rx_dne_mask,
   input logic                        tx_int_enable,
   input logic                        rx_int_enable,
   //input logic [15:0]                 rx_byte_wait,
   input logic [63:0]                 host_tx_dne_offset,
   input logic [63:0]                 host_tx_dne_mask,
   input logic [63:0]                 host_rx_dne_offset,
   input logic [63:0]                 host_rx_dne_mask,
   input logic [63:0]                 host_rx_pkt_offset,
   input logic [63:0]                 host_rx_pkt_mask,
   input logic [63:0]                 host_rx_pkt_head,
   input logic                        host_rx_pkt_ready,

   // pcie write queue interface
   output logic                       wr_q_enq_en,
   output logic [`WR_Q_WIDTH-1:0]     wr_q_enq_data,
   input logic                        wr_q_almost_full,
   input logic                        wr_q_full,
   
   // MAC interface
   input logic [63:0]                 S_AXIS_TDATA,
   input logic [7:0]                  S_AXIS_TSTRB,
   input logic                        S_AXIS_TVALID,
   output logic                       S_AXIS_TREADY,
   input logic                        S_AXIS_TLAST,
   input logic [127:0]                S_AXIS_TUSER,

   // stats
   output logic [63:0]                stat_mac_rx_ts,
   output logic [31:0]                stat_mac_rx_word_cnt,
   output logic [31:0]                stat_mac_rx_pkt_cnt,
   output logic [31:0]                stat_mac_rx_err_cnt,

   // misc
   input logic                        clk,
   input logic                        rst
   );
   
   // ----------------------------------
   // -- mem pointers
   // ----------------------------------
   //logic [`MEM_ADDR_BITS-1:0]        mem_rx_dsc_head, mem_rx_dsc_head_nxt;
   
   logic [`MEM_ADDR_BITS-1:0]        mem_rx_pkt_tail, mem_rx_pkt_tail_nxt;

   logic [`MEM_ADDR_BITS-1:0]        mem_rx_dne_head, mem_rx_dne_head_nxt;
   logic [`MEM_ADDR_BITS-1:0]        mem_rx_dne_tail, mem_rx_dne_tail_nxt;
   logic [`MEM_ADDR_BITS-1:0]        mem_rx_dne_clear;

   logic [`MEM_ADDR_BITS-1:0]        mem_tx_dne_head, mem_tx_dne_head_nxt;

   logic [63:0]                      host_rx_pkt_tail, host_rx_pkt_tail_nxt;

   // ----------------------------------
   // -- stats
   // ----------------------------------
   logic [63:0]                      time_stamp;
   logic [63:0]                      stat_mac_rx_ts_nxt;
   logic [31:0]                      stat_mac_rx_word_cnt_nxt;
   logic [31:0]                      stat_mac_rx_pkt_cnt_nxt;
   logic [31:0]                      stat_mac_rx_err_cnt_nxt;

   always_comb begin
      stat_mac_rx_ts_nxt       = stat_mac_rx_ts;
      stat_mac_rx_word_cnt_nxt = stat_mac_rx_word_cnt;
      stat_mac_rx_pkt_cnt_nxt  = stat_mac_rx_pkt_cnt;

      if(S_AXIS_TVALID & S_AXIS_TREADY) begin
         stat_mac_rx_ts_nxt        = time_stamp;
         stat_mac_rx_word_cnt_nxt  = stat_mac_rx_word_cnt + 1;
         if(S_AXIS_TLAST) 
           stat_mac_rx_pkt_cnt_nxt = stat_mac_rx_pkt_cnt_nxt + 1;
      end
   end
   
   always_ff @(posedge clk) begin
      if(rst) begin
         time_stamp           <= 0;
         stat_mac_rx_ts       <= 0;
         stat_mac_rx_word_cnt <= 0;
         stat_mac_rx_pkt_cnt  <= 0;
      end
      else begin
         time_stamp           <= time_stamp + 1;
         stat_mac_rx_ts       <= stat_mac_rx_ts_nxt;
         stat_mac_rx_word_cnt <= stat_mac_rx_word_cnt_nxt;
         stat_mac_rx_pkt_cnt  <= stat_mac_rx_pkt_cnt_nxt;
      end
   end
   
   // ----------------------------------
   // -- Send a DMA write/interrupt
   // ----------------------------------
   localparam DMA_WR_STATE_IDLE = 0;
   localparam DMA_WR_STATE_INTR = 1;

   logic                             dma_wr_state, dma_wr_state_nxt;
   logic                             dma_wr_intr_data, dma_wr_intr_data_nxt;        

   logic                             dma_wr_go, dma_wr_go_nxt;
   logic                             dma_wr_rdy;
   logic [63:0]                      dma_wr_host_addr, dma_wr_host_addr_nxt;
   logic [`MEM_ADDR_BITS-1:0]        dma_wr_local_addr, dma_wr_local_addr_nxt;            
   logic [15:0]                      dma_wr_len, dma_wr_len_nxt;
   //logic [15:0]                      dma_rx_byte, dma_rx_byte_nxt;

   logic                             wr_q_enq_en_nxt;
   logic [`WR_Q_WIDTH-1:0]           wr_q_enq_data_nxt;
   
   always_comb begin
      dma_wr_state_nxt = dma_wr_state;
      dma_wr_intr_data_nxt = dma_wr_intr_data;
      
      mem_rx_dne_head_nxt = mem_rx_dne_head;
      mem_tx_dne_head_nxt = mem_tx_dne_head;
      
      if(~wr_q_full) begin
         wr_q_enq_en_nxt = 0;
         wr_q_enq_data_nxt = 0;
      end
      else begin
         wr_q_enq_en_nxt = wr_q_enq_en;
         wr_q_enq_data_nxt = wr_q_enq_data;
      end
      
      dma_wr_rdy = ~wr_q_almost_full;

      mem_vld_rx_dne_rd_addr = mem_rx_dne_head[`MEM_ADDR_BITS-1:11];
      mem_vld_tx_dne_rd_addr = mem_tx_dne_head[`MEM_ADDR_BITS-1:11];
      
      case(dma_wr_state)
        DMA_WR_STATE_IDLE: begin      
           if(~wr_q_full) begin
              if(dma_wr_go) begin
                 wr_q_enq_data_nxt[21:6] = dma_wr_len; // byte len
                 wr_q_enq_data_nxt[25:22] = `ID_MEM_RX_PKT; // mem select
                 wr_q_enq_data_nxt[89:26] = dma_wr_host_addr; // host address
                 wr_q_enq_data_nxt[90+:`MEM_ADDR_BITS] = dma_wr_local_addr; // address                                    
                 wr_q_enq_en_nxt = 1;
              end
              else if(mem_vld_rx_dne_rd_bits[mem_rx_dne_head[10:6]]) begin
                 mem_rx_dne_head_nxt    = (mem_rx_dne_head + 64) & rx_dne_mask[`MEM_ADDR_BITS-1:0];
                 mem_vld_rx_dne_rd_addr = mem_rx_dne_head_nxt[`MEM_ADDR_BITS-1:11];
                 
                 wr_q_enq_data_nxt[25:22] = `ID_MEM_RX_DNE; // mem select
                 wr_q_enq_data_nxt[21:6] = 16; // byte len
                 wr_q_enq_data_nxt[90+:`MEM_ADDR_BITS] = mem_rx_dne_head;
                 wr_q_enq_data_nxt[89:26] = (host_rx_dne_offset & ~host_rx_dne_mask) |
                                            ({{($bits(host_rx_dne_mask)-`MEM_ADDR_BITS){1'b0}}, mem_rx_dne_head} & host_rx_dne_mask); // host address
                 wr_q_enq_en_nxt = 1;
                 if(rx_int_enable) begin
                    dma_wr_intr_data_nxt = 0;
                    dma_wr_state_nxt = DMA_WR_STATE_INTR;                    
                 end
              end
              else if(mem_vld_tx_dne_rd_bits[mem_tx_dne_head[10:6]]) begin
                 mem_tx_dne_head_nxt    = (mem_tx_dne_head + 64) & tx_dne_mask[`MEM_ADDR_BITS-1:0];
                 mem_vld_tx_dne_rd_addr = mem_tx_dne_head_nxt[`MEM_ADDR_BITS-1:11];
                 
                 wr_q_enq_data_nxt[21:6] = 4; // byte len
                 wr_q_enq_data_nxt[25:22] = `ID_MEM_TX_DNE; // mem select
                 wr_q_enq_data_nxt[89:26] = (host_tx_dne_offset & ~host_tx_dne_mask) | 
                                            ({{($bits(host_tx_dne_mask)-`MEM_ADDR_BITS){1'b0}}, mem_tx_dne_head} & host_tx_dne_mask); // host address
                 wr_q_enq_data_nxt[90+:`MEM_ADDR_BITS] = mem_tx_dne_head; // address                   
                 wr_q_enq_en_nxt = 1;
                 if(tx_int_enable) begin
                    dma_wr_intr_data_nxt = 1;
                    dma_wr_state_nxt = DMA_WR_STATE_INTR;
                 end
              end
           end
        end
        DMA_WR_STATE_INTR: begin
           if(~wr_q_full) begin
              if(dma_wr_go) begin
                 wr_q_enq_data_nxt[21:6] = dma_wr_len; // byte len
                 wr_q_enq_data_nxt[25:22] = `ID_MEM_RX_PKT; // mem select
                 wr_q_enq_data_nxt[89:26] = dma_wr_host_addr; // host address
                 wr_q_enq_data_nxt[90+:`MEM_ADDR_BITS] = dma_wr_local_addr; // address                                    
                 wr_q_enq_en_nxt = 1;
              end
              else begin
                 wr_q_enq_data_nxt[0] = 1; // interrupt
                 wr_q_enq_data_nxt[1] = dma_wr_intr_data;
                 wr_q_enq_en_nxt = 1;              
                 dma_wr_state_nxt = DMA_WR_STATE_IDLE;
              end
           end
        end
      endcase         
   end

   always_ff @(posedge clk) begin
      if(rst) begin
         dma_wr_state    <= DMA_WR_STATE_IDLE;
         mem_rx_dne_head <= 0;
         mem_tx_dne_head <= 0;
         wr_q_enq_en     <= 0;
      end
      else begin
         dma_wr_state    <= dma_wr_state_nxt;
         mem_tx_dne_head <= mem_tx_dne_head_nxt;
         mem_rx_dne_head <= mem_rx_dne_head_nxt;
         wr_q_enq_en     <= wr_q_enq_en_nxt;
      end

      dma_wr_intr_data <= dma_wr_intr_data_nxt;
      wr_q_enq_data <= wr_q_enq_data_nxt;

   end
  
   // ----------------------------------------
   // -- Process packet coming from the MAC
   // ----------------------------------------

   // the host ring buffer is required to be 64 Bytes aligned
   localparam MAC_RX_STATE_WAIT = 0;
   localparam MAC_RX_STATE_IDLE = 1;
   localparam MAC_RX_STATE_DATA = 2;
   localparam MAC_RX_STATE_DROP = 3;

   logic [2:0] mac_rx_state, mac_rx_state_nxt;
   logic [15:0] pkt_len_reg, pkt_len_reg_nxt;
   //logic [15:0] pkt_port_reg, pkt_port_reg_nxt;
   logic [63:0] timestamp_reg, timestamp_reg_nxt;
   logic [15:0] rx_bytes, rx_bytes_nxt;
   wire [15:0] rx_bytes_plus_8;
   assign rx_bytes_plus_8 = rx_bytes + 8;
   logic [19:0] mem_rx_pkt_tail_reg, mem_rx_pkt_tail_reg_nxt;

   logic [63:0] host_rx_pkt_space_left;
   logic [19:0] mem_rx_pkt_space_left;

   logic rx_dne_ready;
   assign rx_dne_ready = (((mem_rx_dne_tail + 64*8) & rx_dne_mask[`MEM_ADDR_BITS-1:0]) != host_rx_dne_head[`MEM_ADDR_BITS-1:0]);
   logic rx_dne_ready_reg;

   always_comb begin

      mac_rx_state_nxt = mac_rx_state;
      host_rx_pkt_tail_nxt = host_rx_pkt_tail;
      pkt_len_reg_nxt = pkt_len_reg;
      //pkt_port_reg_nxt = pkt_port_reg;
      timestamp_reg_nxt = timestamp_reg;
      rx_bytes_nxt = rx_bytes;
      mem_rx_pkt_tail_reg_nxt = mem_rx_pkt_tail_reg;

      S_AXIS_TREADY = 1;

      mem_rx_pkt_wr_addr  = mem_rx_pkt_tail;
      mem_rx_pkt_wr_mask  = 8'hff;
      mem_rx_pkt_wr_data  = 0;
      mem_rx_pkt_wr_en    = 0;
      mem_rx_pkt_tail_nxt = mem_rx_pkt_tail;      

      mem_rx_dne_wr_en     = 0;
      mem_rx_dne_wr_mask   = 8'hff;
      mem_rx_dne_wr_data   = 0;
      mem_rx_dne_wr_addr   = mem_rx_dne_tail;
      mem_rx_dne_tail_nxt  = mem_rx_dne_tail;

      mem_rx_dne_clear        = (mem_rx_dne_tail + 64*8) & rx_dne_mask[`MEM_ADDR_BITS-1:0];
      mem_vld_rx_dne_wr_addr  = mem_rx_dne_clear[`MEM_ADDR_BITS-1:11];
      mem_vld_rx_dne_wr_mask  = 1 << mem_rx_dne_clear[10:6];
      mem_vld_rx_dne_wr_clear = 0;

      dma_wr_go_nxt         = 0;
      dma_wr_local_addr_nxt = dma_wr_local_addr;
      dma_wr_host_addr_nxt  = dma_wr_host_addr;
      dma_wr_len_nxt        = dma_wr_len;

      if(host_rx_pkt_tail >= host_rx_pkt_head) begin
         host_rx_pkt_space_left = host_rx_pkt_head - host_rx_pkt_tail + host_rx_pkt_mask - 64'd63;
      end
      else begin
         host_rx_pkt_space_left = host_rx_pkt_head - host_rx_pkt_tail - 64'd64;
      end

      if(mem_rx_pkt_tail >= mem_rx_pkt_head[19:0]) begin
         mem_rx_pkt_space_left = mem_rx_pkt_head[19:0] - mem_rx_pkt_tail + rx_pkt_mask[19:0] - 20'd63;
      end
      else begin
         mem_rx_pkt_space_left = mem_rx_pkt_head[19:0] - mem_rx_pkt_tail - 20'd64;
      end

      case(mac_rx_state)
         MAC_RX_STATE_WAIT: begin
            S_AXIS_TREADY = 0;
            rx_bytes_nxt = 0;
            if(host_rx_pkt_ready && host_rx_pkt_space_left>=64'd1536 && mem_rx_pkt_space_left>=20'd1536) begin
               mac_rx_state_nxt = MAC_RX_STATE_IDLE;
            end
         end

         MAC_RX_STATE_IDLE: begin
            if(~mem_vld_rx_dne_wr_stall && rx_dne_ready_reg) begin
               if(S_AXIS_TVALID) begin
                  if(!S_AXIS_TLAST && S_AXIS_TUSER[15:0] <= 1536) begin
                     mac_rx_state_nxt = MAC_RX_STATE_DATA;
                     //pkt_port_reg_nxt = S_AXIS_TUSER[31:16];
                     timestamp_reg_nxt = S_AXIS_TUSER[95:32];
                     rx_bytes_nxt = rx_bytes_plus_8;

                     // generate RX interrupt
                     mem_rx_dne_wr_en = 1;
                     mem_rx_dne_wr_mask = 8'hff;
                     mem_rx_dne_tail_nxt = (mem_rx_dne_tail + 8) & rx_dne_mask[`MEM_ADDR_BITS-1:0];
                     mem_vld_rx_dne_wr_clear = 1;
                     mem_rx_dne_wr_data[31:0] = S_AXIS_TUSER[31:0];

                     mem_rx_pkt_wr_en = 1;
                     mem_rx_pkt_wr_data = S_AXIS_TDATA;
                     mem_rx_pkt_tail_nxt = (mem_rx_pkt_tail + 8) & rx_pkt_mask[`MEM_ADDR_BITS-1:0];

                     dma_wr_local_addr_nxt = mem_rx_pkt_tail;
                     dma_wr_host_addr_nxt = host_rx_pkt_offset + host_rx_pkt_tail;
                     //dma_wr_len_nxt = S_AXIS_TUSER[15:0];
                     if(S_AXIS_TUSER[5:0] == 0) begin
                        pkt_len_reg_nxt = S_AXIS_TUSER[15:0];
                        mem_rx_pkt_tail_reg_nxt = (mem_rx_pkt_tail + {4'b0, S_AXIS_TUSER[15:0]}) & rx_pkt_mask[`MEM_ADDR_BITS-1:0];
                        host_rx_pkt_tail_nxt = (host_rx_pkt_tail + {48'b0, S_AXIS_TUSER[15:0]}) & host_rx_pkt_mask;
                     end
                     else begin
                        pkt_len_reg_nxt = {S_AXIS_TUSER[15:6], 6'b0} + 64;
                        mem_rx_pkt_tail_reg_nxt = (mem_rx_pkt_tail + {4'b0, S_AXIS_TUSER[15:6], 6'b0} + 64) & rx_pkt_mask[`MEM_ADDR_BITS-1:0];
                        host_rx_pkt_tail_nxt = (host_rx_pkt_tail + {48'b0, S_AXIS_TUSER[15:6], 6'b0} + 64) & host_rx_pkt_mask;
                     end
                  end
                  else if(!S_AXIS_TLAST) begin
                     mac_rx_state_nxt = MAC_RX_STATE_DROP;
                  end
               end
            end
            else begin
               S_AXIS_TREADY = 0;
            end
         end

         MAC_RX_STATE_DATA: begin
            if(dma_wr_rdy) begin
               if(S_AXIS_TVALID) begin
                  if(!S_AXIS_TLAST) begin
                     if(rx_bytes_plus_8 < pkt_len_reg) begin
                        rx_bytes_nxt = rx_bytes_plus_8;
                        mem_rx_pkt_wr_en = 1;
                        mem_rx_pkt_wr_data = S_AXIS_TDATA;
                        mem_rx_pkt_tail_nxt = (mem_rx_pkt_tail + 8) & rx_pkt_mask[`MEM_ADDR_BITS-1:0];
                     end
                     else if(rx_bytes_plus_8 == pkt_len_reg) begin
                        mem_rx_pkt_wr_en = 1;
                        mem_rx_pkt_wr_data = S_AXIS_TDATA;
                        mem_rx_pkt_tail_nxt = mem_rx_pkt_tail_reg;

                        dma_wr_len_nxt = pkt_len_reg;
                        dma_wr_go_nxt = 1;

                        // generate RX interrupt
                        mem_rx_dne_wr_en = 1;
                        mem_rx_dne_wr_mask = 8'hff;
                        mem_rx_dne_tail_nxt = (mem_rx_dne_tail + 56) & rx_dne_mask[`MEM_ADDR_BITS-1:0];
                        mem_rx_dne_wr_data[63:0] = timestamp_reg;

                        mac_rx_state_nxt = MAC_RX_STATE_DROP;
                     end
                  end
                  else begin
                     mem_rx_pkt_wr_en = 1;
                     mem_rx_pkt_tail_nxt = mem_rx_pkt_tail_reg;
                     case(S_AXIS_TSTRB)
                        8'h01: begin
                           dma_wr_len_nxt = rx_bytes + 1;
                           mem_rx_pkt_wr_data = {56'b0, S_AXIS_TDATA[7:0]};
                        end
                        8'h03: begin
                           dma_wr_len_nxt = rx_bytes + 2;
                           mem_rx_pkt_wr_data = {48'b0, S_AXIS_TDATA[15:0]};
                        end
                        8'h07: begin
                           dma_wr_len_nxt = rx_bytes + 3;
                           mem_rx_pkt_wr_data = {40'b0, S_AXIS_TDATA[23:0]};
                        end
                        8'h0f: begin
                           dma_wr_len_nxt = rx_bytes + 4;
                           mem_rx_pkt_wr_data = {32'b0, S_AXIS_TDATA[31:0]};
                        end
                        8'h1f: begin
                           dma_wr_len_nxt = rx_bytes + 5;
                           mem_rx_pkt_wr_data = {24'b0, S_AXIS_TDATA[39:0]};
                        end
                        8'h3f: begin
                           dma_wr_len_nxt = rx_bytes + 6;
                           mem_rx_pkt_wr_data = {16'b0, S_AXIS_TDATA[47:0]};
                        end
                        8'h7f: begin
                           dma_wr_len_nxt = rx_bytes + 7;
                           mem_rx_pkt_wr_data = {8'b0, S_AXIS_TDATA[55:0]};
                        end
                        8'hff: begin
                           dma_wr_len_nxt = rx_bytes + 8;
                           mem_rx_pkt_wr_data = S_AXIS_TDATA;
                        end
                        default: begin
                           dma_wr_len_nxt = rx_bytes + 8;
                           mem_rx_pkt_wr_data = S_AXIS_TDATA;
                        end
                     endcase
                     mac_rx_state_nxt = MAC_RX_STATE_WAIT;
                     dma_wr_go_nxt = 1;

                     // generate RX interrupt
                     mem_rx_dne_wr_en = 1;
                     mem_rx_dne_wr_mask = 8'hff;
                     mem_rx_dne_tail_nxt = (mem_rx_dne_tail + 56) & rx_dne_mask[`MEM_ADDR_BITS-1:0];
                     mem_rx_dne_wr_data[63:0] = timestamp_reg;
                  end
               end
            end
            else begin
               S_AXIS_TREADY = 0;
            end
         end

         MAC_RX_STATE_DROP: begin
            if(S_AXIS_TVALID && S_AXIS_TLAST) begin
               mac_rx_state_nxt = MAC_RX_STATE_WAIT;
            end
         end
      endcase
   end

   always_ff @(posedge clk) begin
      if(rst) begin
         mac_rx_state <= MAC_RX_STATE_WAIT;
         host_rx_pkt_tail <= 0;
         pkt_len_reg <= 0;
         //pkt_port_reg <= 0;
         timestamp_reg <= 0;
         rx_bytes <= 0;
         mem_rx_pkt_tail_reg <= 0;
         mem_rx_pkt_tail <= 0;
         mem_rx_dne_tail <= 0;
         dma_wr_go <= 0;
         dma_wr_local_addr <= 0;
         dma_wr_host_addr <= 0;
         dma_wr_len <= 0;
      end
      else begin
         mac_rx_state <= mac_rx_state_nxt;
         host_rx_pkt_tail <= host_rx_pkt_tail_nxt;
         pkt_len_reg <= pkt_len_reg_nxt;
         //pkt_port_reg <= pkt_port_reg_nxt;
         timestamp_reg <= timestamp_reg_nxt;
         rx_bytes <= rx_bytes_nxt;
         mem_rx_pkt_tail_reg <= mem_rx_pkt_tail_reg_nxt;
         mem_rx_pkt_tail <= mem_rx_pkt_tail_nxt;
         mem_rx_dne_tail <= mem_rx_dne_tail_nxt;
         dma_wr_go <= dma_wr_go_nxt;
         dma_wr_local_addr <= dma_wr_local_addr_nxt;
         dma_wr_host_addr <= dma_wr_host_addr_nxt;
         dma_wr_len <= dma_wr_len_nxt;
      end
      rx_dne_ready_reg <= rx_dne_ready;
   end

endmodule
