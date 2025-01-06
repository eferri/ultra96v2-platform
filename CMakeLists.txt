cmake_minimum_required(VERSION 3.22)

project(ultra96v2-hw-sensors LANGUAGES CXX)

# Remove src/ prefix from filelist
file(STRINGS sources.f VERILOG_FILELIST)
string(REGEX REPLACE "src/" " " VERILOG_FILELIST ${VERILOG_FILELIST})
separate_arguments(VERILOG_FILELIST)

add_subdirectory(src)
