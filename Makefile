SRC_DIR := .
PROGRAMS := prototype
CC := gcc
CFLAGS := -Wall -Wextra -Werror -I.

build: $(PROGRAMS)

format:
	find $(SRC_DIR) -iname '*.[hc]' | xargs clang-format -i --style=GNU

clean:
	rm -rf $(PROGRAMS) *.o

.PHONY: build format clean
