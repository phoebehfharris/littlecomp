#!/usr/bin/env sh

as output.s -o output.o --32
ld output.o -o output -m elf_i386
