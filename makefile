test_synchronizer: ./test/synchronizer/test_synchronizer.cpp
	verilator --cc --exe --trace --build -j 0 -Wall --top-module test_synchronizer ./test/synchronizer/test_synchronizer.cpp ./src/synchronizer/master_requester.v ./src/synchronizer/two_flop_sync.v ./test/synchronizer/slave_responder.v ./test/synchronizer/test_synchronizer.v -o test_synchronizer

	./obj_dir/test_synchronizer


test_alu: ./test/alu/test_alu.cpp
	verilator --cc --exe --trace --build -j 0 -Wall --top-module alu ./test/alu/test_alu.cpp ./src/alu/alu.v -o test_alu

	./obj_dir/test_alu


test_memory_controller: ./test/memory_controller/test_mem_controller.cpp
	verilator --cc --exe --timing --trace --build -j 0 --top-module memory_controller ./test/memory_controller/test_mem_controller.cpp ./src/memory/memory_controller.v ./src/memory/sky130_sram_1kbyte_1rw1r_32x256_8.bb.v ./src/synchronizer/master_requester.v ./src/synchronizer/two_flop_sync.v -o test_memory_controller

	./obj_dir/test_memory_controller

test_cpu_core: ./test/cpu_core/test_cpu.cpp
	verilator --cc --exe --timing --trace --build -j 0 --top-module cpu_core ./test/cpu_core/test_cpu.cpp ./src/cpu_core/cpu_core.v ./src/alu/alu.v ./src/register_file/register_file.v ./src/memory/memory_controller.v ./src/memory/sky130_sram_1kbyte_1rw1r_32x256_8.bb.v ./src/synchronizer/master_requester.v ./src/synchronizer/two_flop_sync.v -o test_cpu_core

	./obj_dir/test_cpu_core

test_all: test_synchronizer test_alu test_memory_controller test_cpu_core
	echo "All tests completed successfully."


vlsi_alu: ./src/alu/alu.v ./vlsi/alu/config.json ./vlsi/alu/pins.cfg
	openlane --flow classic ./vlsi/alu/config.json
	latest_run=$$(ls -td vlsi/alu/runs/RUN_* 2>/dev/null | head -1); \
	echo "$$latest_run"; \
	cp -r "$$latest_run/final/." vlsi/alu/final_design;

vlsi_register_file: ./src/register_file/register_file.v ./vlsi/register_file/config.json ./vlsi/register_file/pins.cfg
	openlane --flow classic ./vlsi/register_file/config.json
	latest_run=$$(ls -td vlsi/register_file/runs/RUN_* 2>/dev/null | head -1); \
	echo "$$latest_run"; \
	cp -r "$$latest_run/final/." vlsi/register_file/final_design;

vlsi_cpu_core: ./src/cpu_core/cpu_core.v ./vlsi/config.json ./vlsi/pins.cfg vlsi_alu vlsi_register_file
	openlane --flow classic ./vlsi/config.json
	latest_run=$$(ls -td vlsi/runs/RUN_* 2>/dev/null | head -1); \
	echo "$$latest_run"; \
	cp -r "$$latest_run/final/." vlsi/final_design;

vlsi_view_cpu_core_klayout: ./vlsi/final_design/klayout_gds/cpu_core.klayout.gds
	klayout ./vlsi/final_design/klayout_gds/cpu_core.klayout.gds

assemble: ./utils/assembler/assembler.py
	python3 ./utils/assembler/assembler.py $(ARGS)

compile_simulator: ./utils/simulator/sim_cpu.cpp ./src/cpu_core/cpu_core.v
	verilator --cc --exe --timing --trace --build -j 0 --top-module cpu_core ./utils/simulator/sim_cpu.cpp ./src/cpu_core/cpu_core.v ./src/alu/alu.v ./src/register_file/register_file.v ./src/memory/memory_controller.v ./src/memory/sky130_sram_1kbyte_1rw1r_32x256_8.bb.v ./src/synchronizer/master_requester.v ./src/synchronizer/two_flop_sync.v -o cpu_simulator

cpu_simulator: compile_simulator
	./obj_dir/cpu_simulator $(ARGS)

clean:
	rm -rf ./obj_dir
	rm -rf ./vlsi/alu/final_design
	rm -rf ./vlsi/register_file/final_design