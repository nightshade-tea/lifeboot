SRC := lifeboot.asm
BIN := boot.bin
QEMU := qemu-system-i386

$(BIN): $(SRC)
	nasm $(SRC) -f bin -o $(BIN)

run: $(BIN)
	$(QEMU) -drive file=$(BIN),format=raw

clean:
	rm -f $(BIN)

.PHONY: run clean
