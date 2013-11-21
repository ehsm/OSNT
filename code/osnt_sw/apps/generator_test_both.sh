#!/bin/bash

case "$1" in

load_simple_test)  
	# Extracting delay value
	./wraxi 0x76e00000 0x0 # reset 
	./wraxi 0x76e00004 0x0 # enable extraction

	# Set inter packet delay
	# nf0
	./wraxi 0x76600000 0x0 # reset
	./wraxi 0x76600004 0x1 # enable ipd
	./wraxi 0x76600008 0x0 # use register value
	./wraxi 0x7660000C 0x0 # register value

	# nf1
	./wraxi 0x76600010 0x0 # reset
	./wraxi 0x76600014 0x1 # enable ipd
	./wraxi 0x76600018 0x0 # use register value
	./wraxi 0x7660001C 0x0 # register value

	# Set rate limiter
	# nf0
	./wraxi 0x77e00000 0x0 # reset
	./wraxi 0x77e00004 0x1 # enable rate limiter
	./wraxi 0x77e00008 0x10 # rate limit value in bits

	# nf1
	./wraxi 0x77e0000C 0x0 # reset
	./wraxi 0x77e00010 0x1 # enable rate limiter
	./wraxi 0x77e00014 0x10 # rate limit value in bits

	# Pcap engine
	./generator.sh clear

	./generator.sh wr rst 0

	./generator.sh wr nf0_la 0x0
	./generator.sh wr nf0_ha 0x5
	./generator.sh wr nf0_rc 0x10

	./generator.sh wr nf1_la 0x5
	./generator.sh wr nf1_ha 0x16
	./generator.sh wr nf1_rc 0x3

	# Give sometime for the values to settle down
	sleep 1
	./generator.sh wr nf0_en 0x1
	./generator.sh wr nf1_en 0x1

	sleep 1
	tcpreplay --intf1=nf0 nf0.cap 
	tcpreplay --intf1=nf1 nf1.cap

	sleep 1
    	;;
load_delay_test)  
	# Extracting delay value
	./wraxi 0x76e00000 0x0 # reset 
	./wraxi 0x76e00004 0x1 # enable extraction

	# Set inter packet delay
	# nf0
	./wraxi 0x76600000 0x0 # reset
	./wraxi 0x76600004 0x1 # enable ipd
	./wraxi 0x76600008 0x0 # use register value
	./wraxi 0x7660000C 0x0 # register value

	# nf1
	./wraxi 0x76600010 0x0 # reset
	./wraxi 0x76600014 0x1 # enable ipd
	./wraxi 0x76600018 0x0 # use register value
	./wraxi 0x7660001C 0x0 # register value

	# Set rate limiter
	# nf0
	./wraxi 0x77e00000 0x0 # reset
	./wraxi 0x77e00004 0x0 # enable rate limiter
	./wraxi 0x77e00008 0x0 # rate limit value in bits

	# nf1
	./wraxi 0x77e0000C 0x0 # reset
	./wraxi 0x77e00010 0x0 # enable rate limiter
	./wraxi 0x77e00014 0x0 # rate limit value in bits

	# Pcap engine
	./generator.sh clear

	./generator.sh wr rst 0

	./generator.sh wr nf0_la 0x0
	./generator.sh wr nf0_ha 0x5
	./generator.sh wr nf0_rc 0x10

	./generator.sh wr nf1_la 0x35
	./generator.sh wr nf1_ha 0x46
	./generator.sh wr nf1_rc 0x3

	# Give sometime for the values to settle down
	sleep 1
	./generator.sh wr nf0_en 0x1
	./generator.sh wr nf1_en 0x1

	sleep 1
	tcpreplay --intf1=nf0 nf0.cap 
	tcpreplay --intf1=nf1 nf1.cap

	sleep 1
    	;;
run)  
	# Reset Pcap Engine
	./generator.sh wr nf0_en 0x0
	./generator.sh wr nf1_en 0x0
	./generator.sh wr nf1_sr 0x0
	./generator.sh wr nf0_sr 0x0

	# Start Pcap Engine
	./generator.sh wr nf0_en 0x1
	./generator.sh wr nf1_en 0x1
	./generator.sh wr nf1_sr 0x1
	./generator.sh wr nf0_sr 0x1
	;;
*) 
	echo "Argument not specified"
   	;;
esac






