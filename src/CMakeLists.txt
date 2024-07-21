include(ProcessorCount)

ProcessorCount(nproc)

find_package(verilator)

file(STRINGS rtl.f rtl_filelist)

add_executable(sim_tb tb.cpp)
target_compile_features(sim_tb PUBLIC cxx_std_20)

verilate(sim_tb TOP_MODULE top PREFIX Vtop
VERILATOR_ARGS
    -O3
	-Wall
	--verilate-jobs 0
	--threads ${nproc}
	--threads-dpi all
	--timing
	--trace-fst
	--trace-threads 2
	--timescale 1ns/1ns
	--clk top.zynqmp.clk
SOURCES ${rtl_filelist}
)
