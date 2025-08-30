#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Assemble the MBR
nasm -f bin "$SCRIPT_DIR/boot/mbr.asm" -o "$SCRIPT_DIR/boot/mbr.bin" || { echo "Failed to assemble MBR"; exit 1; }

# Assemble the bootloader
nasm -f bin "$SCRIPT_DIR/boot/bootloader.asm" -o "$SCRIPT_DIR/boot/bootloader.bin" || { echo "Failed to assemble Bootloader"; exit 1; }

# Assemble the kernel entry point
nasm -f elf64 "$SCRIPT_DIR/kernel/kernel_entry.asm" -o "$SCRIPT_DIR/kernel/kernel_entry.o" || { echo "Failed to assemble kernel entry"; exit 1; }

# Compile the kernel
x86_64-elf-gcc -m64 -ffreestanding -fno-stack-protector -nostdlib -c "$SCRIPT_DIR/kernel/kernel.c" -o "$SCRIPT_DIR/kernel/kernel.o" || { echo "Failed to compile kernel"; exit 1; }

# Link the kernel to ELF, then convert to flat binary
x86_64-elf-ld -T "$SCRIPT_DIR/kernel/linker.ld" "$SCRIPT_DIR/kernel/kernel_entry.o" "$SCRIPT_DIR/kernel/kernel.o" -o "$SCRIPT_DIR/kernel/kernel.elf" || { echo "Failed to link kernel"; exit 1; }
x86_64-elf-objcopy -O binary "$SCRIPT_DIR/kernel/kernel.elf" "$SCRIPT_DIR/kernel/kernel.bin" || { echo "Failed to objcopy kernel"; exit 1; }

# Create a disk image
# 2880 sectors * 512 bytes = 1.44MB floppy disk image
dd if=/dev/zero of="$SCRIPT_DIR/disk.img" bs=512 count=2880 || { echo "Failed to create disk image"; exit 1; }

# Copy MBR to the first sector of the disk image
dd if="$SCRIPT_DIR/boot/mbr.bin" of="$SCRIPT_DIR/disk.img" bs=512 conv=notrunc || { echo "Failed to copy MBR to disk image"; exit 1; }

# Copy bootloader to the second sector of the disk image
dd if="$SCRIPT_DIR/boot/bootloader.bin" of="$SCRIPT_DIR/disk.img" bs=512 seek=1 conv=notrunc || { echo "Failed to copy Bootloader to disk image"; exit 1; }

# Copy kernel to the disk image starting at sector 18 (after bootloader)
# The bootloader loads 16 sectors (8KB), so we start at sector 17 (0-based indexing)
dd if="$SCRIPT_DIR/kernel/kernel.bin" of="$SCRIPT_DIR/disk.img" bs=512 seek=17 conv=notrunc || { echo "Failed to copy Kernel to disk image"; exit 1; }

echo "Build complete: $SCRIPT_DIR/disk.img"