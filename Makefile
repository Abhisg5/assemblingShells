SHELL = /bin/bash
AS = as
LD = ld
SDK = $(shell xcrun -sdk macosx --show-sdk-path)
ARCH = arm64

SRC = macos_arm64_shell.s
OBJ = macos_arm64_shell.o
BIN = shell

all: $(BIN)

$(BIN): $(OBJ)
	$(LD) -o $@ $^ -lSystem -syslibroot $(SDK) -e _start -arch $(ARCH)

$(OBJ): $(SRC)
	$(AS) -o $@ $<

run: all
	./$(BIN)

clean:
	rm -f $(OBJ) $(BIN) 