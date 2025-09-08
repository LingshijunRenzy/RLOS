# RLOS - ARM64 UEFI Kernel Makefile
# Based on GNU-EFI library

# Compiler settings
ARCH            = aarch64
CROSS_COMPILE   = aarch64-linux-gnu-
CC              = $(CROSS_COMPILE)gcc
LD              = $(CROSS_COMPILE)ld
OBJCOPY         = $(CROSS_COMPILE)objcopy
SIZE            = $(CROSS_COMPILE)size

# GNU-EFI paths
GNUEFI_DIR      = gnu-efi-3.0.9
GNUEFI_INC      = $(GNUEFI_DIR)/inc
GNUEFI_INC_ARCH = $(GNUEFI_DIR)/inc/$(ARCH)
GNUEFI_LIB_DIR  = $(GNUEFI_DIR)/$(ARCH)/lib
GNUEFI_GNUEFI_DIR = $(GNUEFI_DIR)/$(ARCH)/gnuefi
GNUEFI_CRT_OBJS = $(GNUEFI_GNUEFI_DIR)/crt0-efi-$(ARCH).o

# Directories
SRC_DIR         = src/kernel
BUILD_DIR       = build
INCLUDE_DIR     = include

# Output files
EFI_TARGET      = $(BUILD_DIR)/RLOS.efi
SO_TARGET       = $(BUILD_DIR)/RLOS.so
KERNEL_OBJ      = $(BUILD_DIR)/kernel.o

# Compiler flags for UEFI
CPPFLAGS        = -I$(GNUEFI_INC) -I$(GNUEFI_INC_ARCH) -I$(INCLUDE_DIR) \
                  -DEFI_FUNCTION_WRAPPER -DGNU_EFI_USE_MS_ABI

CFLAGS          = -ffreestanding -fno-stack-protector -fpic \
                  -fshort-wchar -mgeneral-regs-only -mcpu=cortex-a57 \
                  -Wall -Wextra -Werror -std=c11 -O2

# Linker settings
LDSCRIPT        = $(GNUEFI_DIR)/gnuefi/elf_$(ARCH)_efi.lds
LDFLAGS         = -nostdlib -znocombreloc -T $(LDSCRIPT) -shared -Bsymbolic \
                  --defsym=EFI_SUBSYSTEM=0xa -s \
                  -L $(GNUEFI_LIB_DIR) -L $(GNUEFI_GNUEFI_DIR)

# Default target
.PHONY: all clean run debug

all: $(EFI_TARGET)

# Build GNU-EFI library first
$(GNUEFI_LIB_DIR)/libefi.a $(GNUEFI_GNUEFI_DIR)/libgnuefi.a:
	$(MAKE) -C $(GNUEFI_DIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE)

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile kernel source
$(KERNEL_OBJ): $(SRC_DIR)/kernel.c | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

# Link to create shared object
$(SO_TARGET): $(KERNEL_OBJ) $(GNUEFI_LIB_DIR)/libefi.a $(GNUEFI_GNUEFI_DIR)/libgnuefi.a
	$(LD) $(LDFLAGS) $(GNUEFI_CRT_OBJS) $(KERNEL_OBJ) -o $@ \
		-lgnuefi -lefi

# Convert to EFI executable  
$(EFI_TARGET): $(SO_TARGET)
	$(OBJCOPY) -j .text -j .sdata -j .data -j .dynamic -j .dynsym \
		-j .rel -j .rela -j .rel.* -j .rela.* -j .reloc \
		-O binary $< $@
	$(SIZE) $<
	@echo ""
	@echo "EFI application built successfully: $@"
	@echo ""

# Run with QEMU
run: $(EFI_TARGET)
	@if [ ! -f /usr/share/AAVMF/AAVMF_CODE.fd ]; then \
		echo "ARM64 UEFI firmware not found. Install with:"; \
		echo "sudo apt install qemu-efi-aarch64"; \
		exit 1; \
	fi
	@if [ ! -f AAVMF_VARS_copy.fd ]; then \
		cp /usr/share/AAVMF/AAVMF_VARS.fd AAVMF_VARS_copy.fd; \
	fi
	@mkdir -p esp/EFI/BOOT
	@cp $(EFI_TARGET) esp/EFI/BOOT/BOOTAA64.EFI
	qemu-system-aarch64 \
		-machine virt,gic-version=3 \
		-cpu cortex-a57 \
		-m 512 \
		-drive if=pflash,format=raw,file=/usr/share/AAVMF/AAVMF_CODE.fd,readonly=on \
		-drive if=pflash,format=raw,file=./AAVMF_VARS_copy.fd \
		-drive file=fat:rw:esp,format=raw \
		-nographic

# Debug version
debug: CFLAGS += -g -DDEBUG
debug: $(EFI_TARGET)

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR) esp
	rm -f AAVMF_VARS_copy.fd
	$(MAKE) -C $(GNUEFI_DIR) clean

# Show help
help:
	@echo "RLOS Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all     - Build the EFI application (default)"
	@echo "  run     - Build and run with QEMU"
	@echo "  debug   - Build debug version"
	@echo "  clean   - Clean all build artifacts"
	@echo "  help    - Show this help message"
	@echo ""
	@echo "Requirements:"
	@echo "  - aarch64-linux-gnu-gcc toolchain"
	@echo "  - qemu-system-aarch64"
	@echo "  - qemu-efi-aarch64 (for UEFI firmware)"