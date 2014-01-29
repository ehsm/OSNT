// Network Protocol Combinations supported


// ETH-IP-TCP/UDP packets
`ifdef PRIORITY_ETH_IPv4_TCPnUDP
	ETH_IPv4_TCPnUDP 
        #(
        	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
                .C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
                .TUPLE_WIDTH(TUPLE_WIDTH),
                .NUM_INPUT_QUEUES(NUM_INPUT_QUEUES),
                .PRTCL_ID_WIDTH(PRTCL_ID_WIDTH),
                .BYTES_COUNT_WIDTH(BYTES_COUNT_WIDTH),
                .ATTRIBUTE_DATA_WIDTH(ATTRIBUTE_DATA_WIDTH)
        ) ETH_IPv4_TCPnUDP_inst
	(
	// --- Interface to the previous stage
		.in_tdata       (pkt_tdata),
                .in_valid       (pkt_tvalid),
                .in_tlast       (pkt_tlast),
                .in_eoh         (pkt_eoh),
                .in_tuser       (pkt_tuser),

                .pkt_valid      (DECLARATIONS_W[`PRIORITY_ETH_IPv4_TCPnUDP].pkt_valid_int),
                .pkt_attributes (DECLARATIONS_W[`PRIORITY_ETH_IPv4_TCPnUDP].pkt_attributes_int),

	// --- Misc
                .reset          (reset),
                .clk            (clk));
`endif

	 
// ETH-VLAN(802.1q/802.1ad)-IP-TCP/UDP packets
`ifdef PRIORITY_ETH_VLAN_IPv4_TCPnUDP
	ETH_VLAN_IPv4_TCPnUDP 
        #(
                .C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
                .C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
                .TUPLE_WIDTH(TUPLE_WIDTH),
                .NUM_INPUT_QUEUES(NUM_INPUT_QUEUES),
                .PRTCL_ID_WIDTH(PRTCL_ID_WIDTH),
                .BYTES_COUNT_WIDTH(BYTES_COUNT_WIDTH),
                .ATTRIBUTE_DATA_WIDTH(ATTRIBUTE_DATA_WIDTH)
        ) ETH_VLAN_IPv4_TCPnUDP_inst
	(
	// --- Interface to the previous stage

                .in_tdata       (pkt_tdata),
                .in_valid       (pkt_tvalid),
                .in_tlast       (pkt_tlast),
                .in_eoh         (pkt_eoh),
                .in_tuser       (pkt_tuser),

                .pkt_valid      (DECLARATIONS_W[`PRIORITY_ETH_VLAN_IPv4_TCPnUDP].pkt_valid_int),
                .pkt_attributes (DECLARATIONS_W[`PRIORITY_ETH_VLAN_IPv4_TCPnUDP].pkt_attributes_int),

	// --- Misc
                .reset          (reset),
                .clk            (clk));
`endif
