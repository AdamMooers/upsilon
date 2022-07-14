cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr)
project(cryosnom1)
include_directories("../firmware")

target_sources(app PRIVATE src/io.c src/dac_adc_test_main.c)
