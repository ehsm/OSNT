./generator.sh clear

./generator.sh wr rst 1
./generator.sh wr rst 0

./generator.sh wr nf0_en 1
./generator.sh wr nf0_la 0
./generator.sh wr nf0_ha 5

./generator.sh wr nf1_en 1
./generator.sh wr nf1_la 5
./generator.sh wr nf1_ha 16

tcpreplay --intf1=nf0 nf0.cap
tcpreplay --intf1=nf1 nf1.cap

./generator.sh wr nf0_rc 5
./generator.sh wr nf1_rc a

./generator.sh wr nf0_sr 1
./generator.sh wr nf1_sr 1
