include(ProcessorCount)

ProcessorCount(nproc)

find_package(VERILATOR)

add_executable(sim_exec tb.cpp)
target_compile_features(sim_exec PUBLIC cxx_std_20)
target_link_libraries(sim_exec tb)

add_library(tb STATIC)
verilate(tb TOP_MODULE tb PREFIX Vtb
VERILATOR_ARGS
	${VERILATOR_EXTRA_ARGS}
	-Wall
	--assert
	--verilate-jobs 0
	--threads 1
	--timing
	--trace-fst
	--trace-threads 1
	--timescale 1ns/1ns
	--clk top.zynqmp.clk
SOURCES ${VERILOG_FILELIST}
)
