.PHONY: all check firmware reference structure uvm-syntax lint sim sim-contention xcelium clean

VERILATOR ?= verilator
PYTHON ?= python3
# Upper address/MMIO bits are intentionally unused at leaf blocks; reset is
# intentionally asynchronous at flops and synchronously observed by assertions;
# two documented sequential blocks use blocking temporaries/reset RAM.
VFLAGS := --timing --trace --assert -DENABLE_SVA -Wall -Wno-fatal \
	-Wno-UNUSEDSIGNAL -Wno-BLKSEQ -Wno-SYNCASYNCNET

all: check uvm-syntax lint sim sim-contention

check: firmware reference structure

firmware:
	$(PYTHON) scripts/build_firmware.py --check

reference:
	$(PYTHON) scripts/reference_model.py

structure:
	$(PYTHON) scripts/structure_check.py

uvm-syntax:
	$(PYTHON) scripts/uvm_syntax_check.py

lint:
	$(VERILATOR) --lint-only $(VFLAGS) --top-module riscv_edge_sensor_hub_soc -f sim/rtl.f

sim:
	mkdir -p build/soc results
	$(VERILATOR) --binary $(VFLAGS) --top-module tb_riscv_edge_sensor_hub \
		-Mdir build/soc -f sim/rtl.f tb/tb_riscv_edge_sensor_hub.sv -o soc_sim
	./build/soc/soc_sim

sim-contention:
	mkdir -p build/contention
	$(VERILATOR) --binary $(VFLAGS) --top-module tb_ecc_sram_contention \
		-Mdir build/contention rtl/memory/ecc_sram.sv tb/tb_ecc_sram_contention.sv \
		-o contention_sim
	./build/contention/contention_sim

xcelium:
	mkdir -p results/xcelium
	xrun -64bit -sv -uvm -uvmhome CDNS-1.2 -timescale 1ns/1ps \
		+define+ENABLE_SVA -f sim/uvm.f -top uvm_tb_top \
		+UVM_TESTNAME=soc_e2e_test +UVM_VERBOSITY=UVM_MEDIUM \
		-seed 1 -coverage all -covoverwrite \
		-l results/xcelium/xrun.log

clean:
	rm -rf build xcelium.d INCA_libs waves.shm results/soc.vcd results/xcelium
