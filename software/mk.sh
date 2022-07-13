#!/bin/sh

set -x

mkdir -p build
cd build
cmake $(cat ../../firmware/overlay.config) -DDTC_OVERLAY_FILE=../firmware/overlay.dts -DBOARD=litex_vexriscv .. && make -j7
