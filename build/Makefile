# Copyright 2023 Peter McGoron
#
# SPDX-License-Identifier: Apache-2.0

.PHONY: images f4pga buildroot litex clone help attach hardware-image \
	buildroot-image litex-f4pga-image \
	upsilon-hardware.tar.gz upsilon-opensbi.tar.gz upsilon-buildroot.tar.gz

###### Images

images: hardware-image buildroot-image opensbi-image



###### Containers

### Hardware container

hardware-image:
	docker build -f Dockerfile.litex_f4pga -t "upsilon-litex-f4pga-env" .
hardware-container:
	docker run -d --name upsilon-hardware upsilon-litex-f4pga-env /bin/sh -c 'while true; do sleep 2; done'
hardware-copy: upsilon-hardware.tar.gz
	# XXX: this always fails if there are very high UIDs, but the
	# file is copied successfully.
	-docker cp upsilon-hardware.tar.gz upsilon-hardware:/home/user/upsilon-hardware.tar.gz
hardware-execute:
	docker exec -ti upsilon-hardware /bin/bash -lc ' \
		tar -xvf upsilon-hardware.tar.gz && \
		cd upsilon/firmware && \
		source ~/conda/xc7/conda/etc/profile.d/conda.sh && \
		conda activate xc7 && \
		make clean && make'
hardware-shell:
	docker exec -ti upsilon-hardware /bin/bash -l
hardware-get:
	docker cp upsilon-hardware:/home/user/upsilon/firmware/build/digilent_arty/gateware/digilent_arty.bit ../boot/
	docker cp upsilon-hardware:/home/user/upsilon/firmware/arty.dtb ../boot/
	docker cp upsilon-hardware:/home/user/upsilon/firmware/csr.json ../boot/
hardware-clean:
	-docker container stop upsilon-hardware
	-docker container rm upsilon-hardware

### OpenSBI Container

opensbi-image: opensbi.tar.gz
	docker build -f Dockerfile.opensbi -t "upsilon-opensbi-env" .
opensbi-container:
	docker run -d --name upsilon-opensbi upsilon-opensbi-env /bin/sh -c 'while true; do sleep 2; done'
opensbi-copy: upsilon-opensbi.tar.gz
	-docker cp upsilon-opensbi.tar.gz upsilon-opensbi:/home/user/upsilon-opensbi.tar.gz
opensbi-get:
	docker cp upsilon-opensbi:/home/user/opensbi/build/platform/litex/vexriscv/firmware/fw_jump.bin ../boot/
opensbi-shell:
	docker exec -ti upsilon-opensbi /bin/bash -l
opensbi-execute:
	docker exec -ti upsilon-opensbi /bin/bash -c ' \
		tar -xvf upsilon-opensbi.tar.gz && \
		cd opensbi && \
		make clean && \
		make CROSS_COMPILE=riscv64-linux-gnu- PLATFORM=litex/vexriscv \
		'
opensbi-clean:
	-docker container stop upsilon-opensbi
	-docker container rm upsilon-opensbi

### Verilator Container

verilator-image:
	docker build -f Dockerfile.verilator -t "upsilon-verilator-env" .
verilator-container:
	docker run -d --name upsilon-verilator upsilon-verilator-env /bin/sh -c 'while true; do sleep 2; done'
verilator-copy: upsilon-hardware.tar.gz
	-docker cp upsilon-hardware.tar.gz upsilon-verilator:/home/user/upsilon-hardware.tar.gz
verilator-shell:
	docker exec -ti upsilon-verilator /bin/bash -l
verilator-execute:
	docker exec -ti upsilon-verilator /bin/bash -c ' \
		tar -xvf upsilon-hardware.tar.gz && \
		cd upsilon/firmware && \
		make clean && \
		make test \
		'
verilator-clean:
	-docker container stop upsilon-verilator
	-docker container rm upsilon-verilator

### Buildroot Container

buildroot-image: buildroot.tar.gz
	docker build -f Dockerfile.buildroot -t "upsilon-buildroot-env" .
buildroot-container:
	docker run -d --name upsilon-buildroot upsilon-buildroot-env /bin/sh -c 'while true; do sleep 2; done'
buildroot-copy: upsilon-buildroot.tar.gz
	-docker cp upsilon-buildroot.tar.gz upsilon-buildroot:/home/user/upsilon-buildroot.tar.gz
buildroot-shell:
	docker exec -ti upsilon-buildroot /bin/bash -l
buildroot-get:
	docker cp upsilon-buildroot:/home/user/buildroot/output/images/Image ../boot/
	docker cp upsilon-buildroot:/home/user/buildroot/output/images/rootfs.cpio ../boot/
buildroot-execute:
	docker exec -ti upsilon-buildroot /bin/bash -c ' \
		tar -xvf upsilon-buildroot.tar.gz && \
		cd buildroot && \
		make clean && \
		make BR2_EXTERNAL=../upsilon/buildroot litex_vexriscv_defconfig && \
		make '
buildroot-clean:
	-docker container stop upsilon-buildroot
	-docker container rm upsilon-buildroot

###### TFTP

tftp:
	cd upsilon/boot && py3tftp --host 192.168.1.100 -p 6969 -v

###### External projects

clone: f4pga buildroot litex opensbi

f4pga:
	if [ ! -d 'f4pga' ]; then \
		git clone https://github.com/chipsalliance/f4pga; \
	fi
	cd f4pga && git checkout main && git pull && \
		git checkout -B upsilon_stable 835a40534f9efd70770d74f56f25fef6cfc6ebc6 \
	tar -czvf f4pga.tar.gz f4pga

buildroot:
	if [ ! -d 'buildroot' ]; then \
		git clone https://git.buildroot.org/buildroot; \
	fi
	cd buildroot && git checkout master && git pull && \
		git checkout -B upsilon_stable 2023.02.1
	tar -czvf buildroot.tar.gz buildroot/

litex:
	if [ ! -d 'litex' ]; then \
		git clone https://github.com/enjoy-digital/litex; \
	fi
	cd litex && git checkout master && git pull && \
		git checkout -B upsilon_stable c6ccb626e88168045edacced3743f6bd98746742

upsilon-hardware.tar.gz:
	tar -czvf upsilon-hardware.tar.gz ../firmware/
upsilon-buildroot.tar.gz:
	tar -czvf upsilon-buildroot.tar.gz ../buildroot/
# This script only works for GNU tar. It renames the extraction directory.
upsilon-opensbi.tar.gz:
	tar -czvf upsilon-opensbi.tar.gz ../opensbi/ --transform 's|opensbi|opensbi/platform|'

opensbi:
	if [ ! -d 'opensbi' ]; then \
		git clone https://github.com/riscv-software-src/opensbi; \
	fi
	cd opensbi && git checkout master && git pull && \
		git checkout -B upsilon_stable v1.2

opensbi.tar.gz:
	tar -czvf opensbi.tar.gz opensbi/