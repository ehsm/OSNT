#!/bin/bash

case "$1" in

wr) 
	case "$2" in

	rst)  
		./wraxi 0x76000000 "$3"
 		./rdaxi 0x76000000
        	;;
	nf0_sr)
		./wraxi 0x76000004 "$3"
 		./rdaxi 0x76000004
        	;;
	nf1_sr)
		./wraxi 0x76000008 "$3"
 		./rdaxi 0x76000008
        	;;
	nf2_sr)
		./wraxi 0x7600000C "$3"
 		./rdaxi 0x7600000C
        	;;
	nf3_sr)
		./wraxi 0x76000010 "$3"
 		./rdaxi 0x76000010
        	;;
	nf0_rc)
		./wraxi 0x76000014 "$3"
 		./rdaxi 0x76000014
        	;;
	nf1_rc)
		./wraxi 0x76000018 "$3"
 		./rdaxi 0x76000018
        	;;
	nf2_rc)
		./wraxi 0x7600001C "$3"
 		./rdaxi 0x7600001C
        	;;
	nf3_rc)
		./wraxi 0x76000020 "$3"
 		./rdaxi 0x76000020
        	;;
	nf0_la)
		./wraxi 0x76000024 "$3"
 		./rdaxi 0x76000024
        	;;
	nf0_ha)
		./wraxi 0x76000028 "$3"
 		./rdaxi 0x76000028
        	;;
	nf1_la)
		./wraxi 0x7600002C "$3"
 		./rdaxi 0x7600002C
        	;;
	nf1_ha)
		./wraxi 0x76000030 "$3"
 		./rdaxi 0x76000030
        	;;
	nf2_la)
		./wraxi 0x76000034 "$3"
 		./rdaxi 0x76000034
        	;;
	nf2_ha)
		./wraxi 0x76000038 "$3"
 		./rdaxi 0x76000038
        	;;
	nf3_la)
		./wraxi 0x7600003C "$3"
 		./rdaxi 0x7600003C
        	;;
	nf3_ha)
		./wraxi 0x76000040 "$3"
 		./rdaxi 0x76000040
        	;;
	nf0_en)
		./wraxi 0x76000044 "$3"
 		./rdaxi 0x76000044
        	;;
	nf1_en)
		./wraxi 0x76000048 "$3"
 		./rdaxi 0x76000048
        	;;	
	nf2_en)
		./wraxi 0x7600004C "$3"
 		./rdaxi 0x7600004C
        	;;
	nf3_en)
		./wraxi 0x76000050 "$3"
 		./rdaxi 0x76000050
        	;;
	*) 	echo "default"
   		;;
	esac
	;;
rd) 
	case "$2" in

	rst)  
 		./rdaxi 0x76000000
        	;;
	nf0_sr)
 		./rdaxi 0x76000004
        	;;
	nf1_sr)
 		./rdaxi 0x76000008
        	;;
	nf2_sr)
 		./rdaxi 0x7600000C
        	;;
	nf3_sr)
 		./rdaxi 0x76000010
        	;;
	nf0_rc)
 		./rdaxi 0x76000014
        	;;
	nf1_rc)
 		./rdaxi 0x76000018
        	;;
	nf2_rc)
 		./rdaxi 0x7600001C
        	;;
	nf3_rc)
 		./rdaxi 0x76000020
        	;;
	nf0_la)
 		./rdaxi 0x76000024
        	;;
	nf0_ha)
 		./rdaxi 0x76000028
        	;;
	nf1_la)
 		./rdaxi 0x7600002C
        	;;
	nf1_ha)
 		./rdaxi 0x76000030
        	;;
	nf2_la)
 		./rdaxi 0x76000034
        	;;
	nf2_ha)
 		./rdaxi 0x76000038
        	;;
	nf3_la)
 		./rdaxi 0x7600003C
        	;;
	nf3_ha)
 		./rdaxi 0x76000040
        	;;
	nf0_en)
 		./rdaxi 0x76000044
        	;;
	nf1_en)
 		./rdaxi 0x76000048
        	;;	
	nf2_en)
 		./rdaxi 0x7600004C
        	;;
	nf3_en)
 		./rdaxi 0x76000050
        	;;
	*) 	echo "default"
   		;;
	esac
	;;

clear)
	./wraxi 0x76000000 1
	./wraxi 0x76000004 0
 	./wraxi 0x76000008 0
 	./wraxi 0x7600000C 0
 	./wraxi 0x76000010 0
 	./wraxi 0x76000014 0
 	./wraxi 0x76000018 0
 	./wraxi 0x7600001C 0
 	./wraxi 0x76000020 0
 	./wraxi 0x76000024 0
 	./wraxi 0x76000028 0
 	./wraxi 0x7600002C 0
 	./wraxi 0x76000030 0
 	./wraxi 0x76000034 0
 	./wraxi 0x76000038 0
 	./wraxi 0x7600003C 0
 	./wraxi 0x76000040 0
 	./wraxi 0x76000044 0
 	./wraxi 0x76000048 0
 	./wraxi 0x7600004C 0
 	./wraxi 0x76000050 0
	;;
*)     	echo "default"
	;;
esac


