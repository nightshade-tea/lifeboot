SRC_DIR := .
PROGRAMS := prototype lifeboot
CC := gcc
CFLAGS := -Wall -Wextra -I.

lifeboot: lifeboot.asm
	nasm lifeboot.asm

all: $(PROGRAMS)

run: lifeboot
	qemu-system-x86_64 -drive file=lifeboot,format=raw

format:
	find $(SRC_DIR) -iname '*.[hc]' | xargs clang-format -i --style=GNU

clean:
	rm -rf $(PROGRAMS) *.o

.PHONY: all run format clean
