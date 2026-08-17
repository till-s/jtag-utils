PROGS=CommandJtagBBTb

VPATH=../../acm-toolbox/hdl:../hdl

run: $(PROGS)
	for i in $^; do ./$$i; done
	echo "All Tests PASSED"

build: $(PROGS)

%.o: %.vhd
	ghdl -a $<

%Tb: %Tb.o
	ghdl -e -o $@ $@

CommandMuxPkg.o: BasicPkg.o

CommandJtagBB.o: CommandMuxPkg.o

CommandJtagBBTb.o: CommandJtagBB.o

.PHONY: all clean

clean:
	$(RM) *.o work-*  $(PROGS)
