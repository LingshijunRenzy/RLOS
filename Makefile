# RLOS - ARM64 Separated Build System
# Complete separation of UEFI Bootloader and Kernel builds
# Linus-style design: clean data structures, eliminate special cases

# =============================================================================
# Compiler Settings
# =============================================================================
ARCH            = aarch64
CROSS_COMPILE   = aarch64-linux-gnu-
CC              = $(CROSS_COMPILE)gcc
LD              = $(CROSS_COMPILE)ld
OBJCOPY         = $(CROSS_COMPILE)objcopy
SIZE            = $(CROSS_COMPILE)size

# =============================================================================
# GNU-EFI Library Settings (bootloader only)
# =============================================================================
GNUEFI_DIR      = gnu-efi-3.0.9
GNUEFI_INC      = $(GNUEFI_DIR)/inc
GNUEFI_INC_ARCH = $(GNUEFI_DIR)/inc/$(ARCH)
GNUEFI_LIB_DIR  = $(GNUEFI_DIR)/$(ARCH)/lib
GNUEFI_GNUEFI_DIR = $(GNUEFI_DIR)/$(ARCH)/gnuefi
GNUEFI_CRT_OBJS = $(GNUEFI_GNUEFI_DIR)/crt0-efi-$(ARCH).o

# =============================================================================
# Directory Settings
# =============================================================================
SRC_DIR         = src
BUILD_DIR       = build
INCLUDE_DIR     = src/include

# Separated source directories
BOOT_SRC_DIR    = $(SRC_DIR)/boot
KERNEL_SRC_DIR  = $(SRC_DIR)/kernel

# Separated build directories  
BOOT_BUILD_DIR  = $(BUILD_DIR)/boot
KERNEL_BUILD_DIR = $(BUILD_DIR)/kernel

# =============================================================================
# Source file discovery - separated boot and kernel
# =============================================================================

# Boot related files (UEFI environment)
BOOT_C_FILES    = $(shell find $(BOOT_SRC_DIR) -name '*.c' 2>/dev/null)
BOOT_S_FILES    = $(shell find $(BOOT_SRC_DIR) -name '*.S' 2>/dev/null)
BOOT_OBJ_FILES  = $(BOOT_C_FILES:$(BOOT_SRC_DIR)/%.c=$(BOOT_BUILD_DIR)/%.o) \
                  $(BOOT_S_FILES:$(BOOT_SRC_DIR)/%.S=$(BOOT_BUILD_DIR)/%.o)

# Kernel related files (bare metal environment)
KERNEL_C_FILES  = $(shell find $(KERNEL_SRC_DIR) -name '*.c' 2>/dev/null)
KERNEL_S_FILES  = $(shell find $(KERNEL_SRC_DIR) -name '*.S' 2>/dev/null)
KERNEL_OBJ_FILES = $(KERNEL_C_FILES:$(KERNEL_SRC_DIR)/%.c=$(KERNEL_BUILD_DIR)/%.o) \
                   $(KERNEL_S_FILES:$(KERNEL_SRC_DIR)/%.S=$(KERNEL_BUILD_DIR)/%.o)

# =============================================================================
# Output files
# =============================================================================
BOOTLOADER_EFI  = $(BUILD_DIR)/bootloader.efi
BOOTLOADER_SO   = $(BUILD_DIR)/bootloader.so
KERNEL_ELF      = $(BUILD_DIR)/kernel.elf

# =============================================================================
# Compile flags - separated UEFI and bare metal environments
# =============================================================================

# Bootloader compile flags (UEFI environment)
BOOT_CPPFLAGS   = -I$(GNUEFI_INC) -I$(GNUEFI_INC_ARCH) -I$(INCLUDE_DIR) \
                  -DEFI_FUNCTION_WRAPPER -DGNU_EFI_USE_MS_ABI \
                  -DBOOT_STAGE

BOOT_CFLAGS     = -ffreestanding -fno-stack-protector -fpic \
                  -fshort-wchar -mgeneral-regs-only -mcpu=cortex-a57 \
                  -Wall -Wextra -Werror -std=c11 -O2

# Kernel compile flags (bare metal environment)
KERNEL_CPPFLAGS = -I$(INCLUDE_DIR) -DKERNEL_STAGE -nostdlib

KERNEL_CFLAGS   = -ffreestanding -fno-stack-protector -fno-builtin \
                  -mgeneral-regs-only -mcpu=cortex-a57 \
                  -Wall -Wextra -Werror -std=c11 -O2

# =============================================================================
# Linker Settings
# =============================================================================

# Bootloader linker settings (UEFI)
BOOT_LDSCRIPT   = $(GNUEFI_DIR)/gnuefi/elf_$(ARCH)_efi.lds
BOOT_LDFLAGS    = -nostdlib -znocombreloc -T $(BOOT_LDSCRIPT) -shared -Bsymbolic \
                  --defsym=EFI_SUBSYSTEM=0xa -s \
                  -L $(GNUEFI_LIB_DIR) -L $(GNUEFI_GNUEFI_DIR)

# Kernel linker settings (bare metal)
KERNEL_LDFLAGS  = -nostdlib -static -T kernel.lds

# =============================================================================
# Build Targets
# =============================================================================
.PHONY: all clean run debug bootloader kernel show-info help

# Build both separated targets by default
all: bootloader kernel

# Build bootloader
bootloader: $(BOOTLOADER_EFI)

# Build kernel  
kernel: $(KERNEL_ELF)

# =============================================================================
# GNU-EFI Library Build
# =============================================================================
$(GNUEFI_LIB_DIR)/libefi.a $(GNUEFI_GNUEFI_DIR)/libgnuefi.a:
	$(MAKE) -C $(GNUEFI_DIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE)

# =============================================================================
# Directory Creation
# =============================================================================
$(BUILD_DIR) $(BOOT_BUILD_DIR) $(KERNEL_BUILD_DIR):
	@mkdir -p $@

# =============================================================================
# Bootloader Build Rules
# =============================================================================

# Compile bootloader C files
$(BOOT_BUILD_DIR)/%.o: $(BOOT_SRC_DIR)/%.c | $(BOOT_BUILD_DIR)
	@mkdir -p $(dir $@)
	@echo "BOOT-CC  $<"
	$(CC) $(BOOT_CPPFLAGS) $(BOOT_CFLAGS) -c $< -o $@

# Compile bootloader assembly files
$(BOOT_BUILD_DIR)/%.o: $(BOOT_SRC_DIR)/%.S | $(BOOT_BUILD_DIR)
	@mkdir -p $(dir $@)
	@echo "BOOT-AS  $<"
	$(CC) $(BOOT_CPPFLAGS) $(BOOT_CFLAGS) -c $< -o $@

# Link bootloader shared object
$(BOOTLOADER_SO): $(BOOT_OBJ_FILES) $(GNUEFI_LIB_DIR)/libefi.a $(GNUEFI_GNUEFI_DIR)/libgnuefi.a | $(BUILD_DIR)
	@echo "BOOT-LD  $@"
	$(LD) $(BOOT_LDFLAGS) $(GNUEFI_CRT_OBJS) $(BOOT_OBJ_FILES) -o $@ \
		-lgnuefi -lefi

# Convert to EFI executable
$(BOOTLOADER_EFI): $(BOOTLOADER_SO)
	@echo "BOOT-EFI $@"
	$(OBJCOPY) -j .text -j .sdata -j .data -j .dynamic -j .dynsym \
		-j .rel -j .rela -j .rel.* -j .rela.* -j .reloc \
		-O binary $< $@
	$(SIZE) $<
	@echo ""
	@echo "Bootloader built: $@"

# =============================================================================
# Kernel Build Rules
# =============================================================================

# Compile kernel C files
$(KERNEL_BUILD_DIR)/%.o: $(KERNEL_SRC_DIR)/%.c | $(KERNEL_BUILD_DIR)
	@mkdir -p $(dir $@)
	@echo "KERN-CC  $<"
	$(CC) $(KERNEL_CPPFLAGS) $(KERNEL_CFLAGS) -c $< -o $@

# Compile kernel assembly files
$(KERNEL_BUILD_DIR)/%.o: $(KERNEL_SRC_DIR)/%.S | $(KERNEL_BUILD_DIR)
	@mkdir -p $(dir $@)
	@echo "KERN-AS  $<"
	$(CC) $(KERNEL_CPPFLAGS) $(KERNEL_CFLAGS) -c $< -o $@

# Create simple kernel linker script
kernel.lds: | $(BUILD_DIR)
	@echo "GEN-LD   $@"
	@echo 'ENTRY(_start)' > $@
	@echo 'SECTIONS' >> $@
	@echo '{' >> $@
	@echo '    . = 0x40080000;' >> $@
	@echo '    ' >> $@
	@echo '    .text : {' >> $@
	@echo '        *(.text*)' >> $@
	@echo '    }' >> $@
	@echo '    ' >> $@
	@echo '    .rodata : {' >> $@
	@echo '        *(.rodata*)' >> $@
	@echo '    }' >> $@
	@echo '    ' >> $@
	@echo '    .data : {' >> $@
	@echo '        *(.data*)' >> $@
	@echo '    }' >> $@
	@echo '    ' >> $@
	@echo '    .bss : {' >> $@
	@echo '        *(.bss*)' >> $@
	@echo '    }' >> $@
	@echo '}' >> $@

# Link kernel ELF
$(KERNEL_ELF): $(KERNEL_OBJ_FILES) kernel.lds | $(BUILD_DIR)
	@echo "KERN-LD  $@"
	$(LD) $(KERNEL_LDFLAGS) $(KERNEL_OBJ_FILES) -o $@
	$(SIZE) $@
	@echo ""
	@echo "Kernel built: $@"

# =============================================================================
# Run and Test
# =============================================================================

# Run bootloader (future: bootloader will load kernel)
run: $(BOOTLOADER_EFI)
	@if [ ! -f /usr/share/AAVMF/AAVMF_CODE.fd ]; then \
		echo "ARM64 UEFI firmware not found. Install with:"; \
		echo "   sudo apt install qemu-efi-aarch64"; \
		exit 1; \
	fi
	@if [ ! -f AAVMF_VARS_copy.fd ]; then \
		cp /usr/share/AAVMF/AAVMF_VARS.fd AAVMF_VARS_copy.fd; \
	fi
	@mkdir -p esp/EFI/BOOT
	@cp $(BOOTLOADER_EFI) esp/EFI/BOOT/BOOTAA64.EFI
	@echo "Starting QEMU with bootloader..."
	qemu-system-aarch64 \
		-machine virt,gic-version=3 \
		-cpu cortex-a57 \
		-m 512 \
		-drive if=pflash,format=raw,file=/usr/share/AAVMF/AAVMF_CODE.fd,readonly=on \
		-drive if=pflash,format=raw,file=./AAVMF_VARS_copy.fd \
		-drive file=fat:rw:esp,format=raw \
		-nographic

# Debug version
debug: BOOT_CFLAGS += -g -DDEBUG
debug: KERNEL_CFLAGS += -g -DDEBUG
debug: all

# =============================================================================
# Clean and Info Display
# =============================================================================

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR) esp kernel.lds
	@rm -f AAVMF_VARS_copy.fd
	@$(MAKE) -C $(GNUEFI_DIR) clean > /dev/null 2>&1 || true
	@echo "Clean completed"

show-info:
	@echo "RLOS Separated Build System"
	@echo ""
	@echo "Bootloader sources:"
	@$(foreach file,$(BOOT_C_FILES),echo "  $(file)";)
	@echo "Bootloader objects:"
	@$(foreach file,$(BOOT_OBJ_FILES),echo "  $(file)";)
	@echo ""
	@echo "Kernel sources:"
	@$(foreach file,$(KERNEL_C_FILES),echo "  $(file)";)
	@echo "Kernel objects:"  
	@$(foreach file,$(KERNEL_OBJ_FILES),echo "  $(file)";)
	@echo ""
	@echo "Outputs:"
	@echo "  Bootloader: $(BOOTLOADER_EFI)"
	@echo "  Kernel: $(KERNEL_ELF)"

help:
	@echo "RLOS Separated Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all        - Build both bootloader and kernel (default)"
	@echo "  bootloader - Build only UEFI bootloader (.efi)"
	@echo "  kernel     - Build only kernel (.elf)"
	@echo "  run        - Build and run bootloader in QEMU"
	@echo "  debug      - Build debug versions"
	@echo "  clean      - Clean all build artifacts"
	@echo "  show-info  - Show discovered files and build info"
	@echo "  help       - Show this help"
	@echo ""
	@echo "Architecture:"
	@echo "  src/boot/     -> build/bootloader.efi (UEFI App)"
	@echo "  src/kernel/   -> build/kernel.elf (Bare Metal)"
	@echo ""
	@echo "Philosophy: 'Good programmers worry about data structures.'"
	@echo "            Clean separation = Good taste!"