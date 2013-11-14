./wraxi 0x76e00000 1

./generator.sh clear

./generator.sh wr rst 0x1

./generator.sh wr nf0_en 0x1
./generator.sh wr nf0_la 0x0
./generator.sh wr nf0_ha 0x5

./generator.sh wr nf1_en 0x1
./generator.sh wr nf1_la 0x15
./generator.sh wr nf1_ha 0x26

./generator.sh wr nf0_rc 0x4
./generator.sh wr nf1_rc 0x1

./generator.sh wr rst 0x0

tcpreplay --intf1=nf0 nf0.cap

sleep 1

tcpreplay --intf1=nf1 nf1.cap

sleep 1

./generator.sh wr rst 0x1
./generator.sh wr rst 0x0

sleep 1

./generator.sh wr nf0_sr 0x1
./generator.sh wr nf1_sr 0x1
