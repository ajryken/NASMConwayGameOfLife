NAME=GameOfLife

all: GameOfLife

clean:
	rm -rf GameOfLife GameOfLife.o

GameOfLife: GameOfLife.asm
	nasm -f elf64 -F dwarf -g GameOfLife.asm
	gcc -g -m64 -o GameOfLife GameOfLife.o -static