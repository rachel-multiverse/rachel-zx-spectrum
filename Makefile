PASMO = /tmp/pasmoNext/pasmo/pasmo

.PHONY: all next spectranet clean

all: next spectranet

next: build/rachel-next.bin
	@echo "Built: build/rachel-next.bin"

spectranet: build/rachel-snet.tap
	@echo "Built: build/rachel-snet.tap"

build/rachel-next.bin: src/main.asm src/*.asm src/net/next.asm
	$(PASMO) --equ NEXT=1 --equ SPECTRANET=0 src/main.asm build/rachel-next.bin

build/rachel-snet.tap: src/main.asm src/*.asm src/net/spectranet.asm
	$(PASMO) --tapbas --equ NEXT=0 --equ SPECTRANET=1 src/main.asm build/rachel-snet.tap

clean:
	rm -rf build/*
