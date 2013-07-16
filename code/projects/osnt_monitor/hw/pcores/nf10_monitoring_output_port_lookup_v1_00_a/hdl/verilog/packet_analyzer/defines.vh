//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------
//  Defines
// ------------------------------------- 

//  Layer2 Protocols
`define ETH_IP						16'h0800
`define ETH_VLAN_Q	 				16'h8100
`define ETH_VLAN_AD                                     16'h9100

//  Layer3 Protocols
`define IP_VER4						4'h4

`define IP_TCP						8'h06
`define IP_UDP						8'h11


// General FLAGS
// to add/remove a flag just comment/uncomment the related line.
`define PKT_FLG_IPv4					0
`define PKT_FLG_TCP					1
`define PKT_FLG_UDP					2
`define PKT_FLG_VLAN_Q					3
`define PKT_FLG_VLAN_AD                                 4					

// Packet FLAG COUNTS 
// must be set accordingly the number of flags defined
`define PKT_FLAGS					5																			

// PRIORITY VALUE = [0], indicates that the given packet does not adhere to any of the following protocol combinations

`define PRIORITY_WHEN_NO_HIT				0
`define PRIORITY_ETH_IPv4_TCPnUDP			1
`define PRIORITY_ETH_VLAN_IPv4_TCPnUDP			2

//////////////////////////////////////////////////////////////////////////////////
