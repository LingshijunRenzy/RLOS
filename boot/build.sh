#!/bin/bash

# Assemble the MBR
nasm -f bin mbr.asm -o mbr.bin || exit 1

# Assemble the bootloader
nasm -f bin bootloader.asm -o bootloader.bin || exit 1

# Create a disk image
# 2880 sectors * 512 bytes = 1.44MB floppy disk image
dd if=/dev/zero of=disk.img bs=512 count=2880

# Copy MBR to the first sector of the disk image
dd if=mbr.bin of=disk.img bs=512 conv=notrunc

# Copy bootloader to the second sector of the disk image
dd if=bootloader.bin of=disk.img bs=512 seek=1 conv=notrunc

echo "Build complete: disk.img"