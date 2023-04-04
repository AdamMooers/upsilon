cmake_minimum_required(VERSION 3.20.0)

# These must come BEFORE the zephyr package declaration.
set(DTC_OVERLAY_FILE "../firmware/overlay.dts")
set(BOARD "litex_vexriscv")
set(EXTRA_CFLAGS "-Wfatal-errors -Werror -Wno-error=unused-const-variable -Wno-error=unused-variable -Wno-error=unused-function")
include("../firmware/overlay.cmake")

find_package(Zephyr)
project(upsilon)
include_directories("../firmware")
include_directories("src/")
include_directories("../creole")
include_directories("../firmware/rtl/control_loop")

# Add all source files here.
target_sources(app PRIVATE src/access.c src/buf.c src/main.c src/sock.c ../creole/creole.c)
