SRC_DIR := .
PROGRAMS := prototype lifeboot
CC := gcc
CFLAGS := -Wall -Wextra -Werror -I.

build: $(PROGRAMS)

lifeboot:
	nasm lifeboot.asm

run:
	qemu-system-x86_64 -drive file=lifeboot,format=raw

format:
	find $(SRC_DIR) -iname '*.[hc]' | xargs clang-format -i --style=GNU

clean:
	rm -rf $(PROGRAMS) *.o

.PHONY: build run format clean
