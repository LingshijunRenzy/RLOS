CROSS ?= x86_64-elf-
CC      := $(CROSS)gcc
AS      := $(CROSS)gcc
LD      := $(CROSS)ld
OBJCOPY := $(CROSS)objcopy
GRUBMKRESCUE ?= grub-mkrescue

# Auto-detect Homebrew cross prefix variant if grub-mkrescue not in PATH
ifeq (,$(shell command -v $(GRUBMKRESCUE) 2>/dev/null))
	GRUBMKRESCUE := x86_64-elf-grub-mkrescue
endif

CFLAGS := -ffreestanding -O2 -Wall -Wextra -mno-red-zone -mcmodel=kernel -fno-stack-protector -fno-pic -fno-plt -nostdlib -nostdinc -fno-builtin -fno-exceptions -I include
CFLAGS += -MMD -MP
LDFLAGS := -nostdlib -z max-page-size=0x1000 -T linker.ld

SRC_ASM := $(wildcard src/boot/*.S)
SRC_C   := $(wildcard src/kernel/*.c)
OBJ     := $(patsubst %.S, build/%.o, $(SRC_ASM)) $(patsubst %.c, build/%.o, $(SRC_C))
DEP     := $(OBJ:.o=.d)

ISO_ROOT := iso_root
ISO_KERNEL_PATH := $(ISO_ROOT)/boot/kernel.elf
ISO_IMAGE := RLOS.iso

.PHONY: all run run-uefi run-bios debug clean distclean

all: $(ISO_IMAGE)

$(ISO_IMAGE): $(ISO_KERNEL_PATH) iso_root/boot/grub/grub.cfg
	$(GRUBMKRESCUE) -o $@ $(ISO_ROOT)

$(ISO_KERNEL_PATH): build/kernel.elf
	@mkdir -p $(dir $@)
	cp $< $@

build/kernel.elf: $(OBJ) linker.ld
	$(LD) $(LDFLAGS) -o $@ $(OBJ)

build/%.o: %.S
	@mkdir -p $(dir $@)
	$(AS) $(CFLAGS) -c $< -o $@

build/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

################################################################################
# Run Targets
# Default 'run' will prefer UEFI if OVMF firmware is found, else fall back to BIOS.
################################################################################

# Try to locate OVMF (Homebrew edk2-ovmf path). Users can override by exporting OVMF_CODE / OVMF_VARS.
OVMF_CODE ?= $(shell test -f /opt/homebrew/opt/edk2-ovmf/share/edk2-ovmf/x64/OVMF_CODE.fd && echo /opt/homebrew/opt/edk2-ovmf/share/edk2-ovmf/x64/OVMF_CODE.fd)
OVMF_VARS ?= $(shell test -f /opt/homebrew/opt/edk2-ovmf/share/edk2-ovmf/x64/OVMF_VARS.fd && echo /opt/homebrew/opt/edk2-ovmf/share/edk2-ovmf/x64/OVMF_VARS.fd)

run: $(ISO_IMAGE)
ifeq (,$(OVMF_CODE))
	@echo "[run] OVMF not found -> using legacy BIOS mode (SeaBIOS)."
	qemu-system-x86_64 -cdrom $(ISO_IMAGE) -serial stdio
else
	@echo "[run] Using UEFI OVMF firmware: $(OVMF_CODE)"
	qemu-system-x86_64 -machine q35 -m 512 -bios $(OVMF_CODE) -cdrom $(ISO_IMAGE) -serial stdio
endif

run-bios: $(ISO_IMAGE)
	qemu-system-x86_64 -cdrom $(ISO_IMAGE) -serial stdio

run-uefi: $(ISO_IMAGE)
ifndef OVMF_CODE
	@echo "OVMF_CODE not set or file missing. Install edk2-ovmf (e.g. 'brew install edk2-ovmf') or export OVMF_CODE path." && exit 1
endif
	qemu-system-x86_64 -machine q35 -m 512 -bios $(OVMF_CODE) -cdrom $(ISO_IMAGE) -serial stdio

# debug: wait for gdb (target remote localhost:1234)
# Use: $(CROSS)gdb build/kernel.elf -ex 'target remote localhost:1234'

debug: $(ISO_IMAGE)
	qemu-system-x86_64 -cdrom $(ISO_IMAGE) -serial stdio -s -S

clean:
	rm -rf build/*.o build/**/*.o build/*.d build/**/*.d build/kernel.elf $(ISO_KERNEL_PATH)

# Deep clean including ISO

distclean: clean
	rm -f $(ISO_IMAGE)

-include $(DEP)
