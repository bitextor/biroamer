cmake_minimum_required(VERSION 2.8 FATAL_ERROR)
project(biroamer)
add_subdirectory(fast_align)
install(TARGETS fast_align atools)
