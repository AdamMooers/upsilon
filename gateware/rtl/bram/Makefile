# Copyright 2024 (C) Peter McGoron
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

.PHONY: codegen

all: codegen
####### Codegen ########

include ../common.makefile
CODEGEN_FILES=bram.v
codegen: ${CODEGEN_FILES}
clean:
	rm -rf obj_dir *.fst ${CODEGEN_FILES}
