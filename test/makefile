PROGS=CommandJtagBBTb JTAGH19EMULTb

VPATH=../../acm-toolbox/hdl:../hdl

run: $(filter-out JTAGH19EMULTb, $(PROGS))
	for i in $^; do echo "Running $$i" && ./$$i; done
	echo "All Tests PASSED"

build: $(PROGS)

%.o: %.vhd
	ghdl -a $<

%Tb: %Tb.o
	ghdl -e -o $@ $@

CommandMuxPkg.o: BasicPkg.o

CommandJtagBB.o: CommandMuxPkg.o

CommandJtagBBTb.o: CommandJtagBB.o

JtagTap.o: JtagTapPkg.o

JTAGH19EMUL.o: JtagTap.o  JtagTapPkg.o

JTAGH19EMULTb.o: JTAGH19EMUL.o

.PHONY: all clean

clean:
	$(RM) *.o work-*  $(PROGS)
