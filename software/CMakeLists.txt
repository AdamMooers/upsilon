cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr)
project(upsilon)
include_directories("../firmware")
include_directories("src/")
include_directories("../creole")
include_directories("../firmware/rtl/control_loop")

target_sources(app PRIVATE src/access.c src/buf.c src/main.c src/sock.c ../creole/creole.c)
