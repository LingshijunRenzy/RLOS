# RLOS - ARM64 UEFI Kernel Makefile
# Based on GNU-EFI library
# Optimized for automatic source file discovery

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
SRC_DIR         = src
BUILD_DIR       = build
INCLUDE_DIR     = include

# Automatic source file discovery
SRC_C_FILES     = $(shell find $(SRC_DIR) -name '*.c' 2>/dev/null)
SRC_S_FILES     = $(shell find $(SRC_DIR) -name '*.S' 2>/dev/null)
SRC_H_FILES     = $(shell find $(SRC_DIR) -name '*.h' 2>/dev/null)
SRC_SUBDIRS     = $(shell find $(SRC_DIR) -type d 2>/dev/null)

# Generate include paths for all source subdirectories
SRC_INCLUDE_DIRS = $(patsubst %,-I%,$(SRC_SUBDIRS))

# Generate object file paths (preserve directory structure in build/)
OBJ_C_FILES     = $(SRC_C_FILES:$(SRC_DIR)/%.c=$(BUILD_DIR)/%.o)
OBJ_S_FILES     = $(SRC_S_FILES:$(SRC_DIR)/%.S=$(BUILD_DIR)/%.o)
ALL_OBJ_FILES   = $(OBJ_C_FILES) $(OBJ_S_FILES)

# Output files
EFI_TARGET      = $(BUILD_DIR)/RLOS.efi
SO_TARGET       = $(BUILD_DIR)/RLOS.so

# Debug output (can be enabled with make VERBOSE=1)
ifdef VERBOSE
$(info Source C files: $(SRC_C_FILES))
$(info Source S files: $(SRC_S_FILES))
$(info Source H files: $(SRC_H_FILES))
$(info Object files: $(ALL_OBJ_FILES))
$(info Include directories: $(SRC_INCLUDE_DIRS))
endif

# Compiler flags for UEFI
CPPFLAGS        = -I$(GNUEFI_INC) -I$(GNUEFI_INC_ARCH) -I$(INCLUDE_DIR) \
                  $(SRC_INCLUDE_DIRS) \
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
.PHONY: all clean run debug show-sources show-dirs help

all: $(EFI_TARGET)

# Build GNU-EFI library first
$(GNUEFI_LIB_DIR)/libefi.a $(GNUEFI_GNUEFI_DIR)/libgnuefi.a:
	$(MAKE) -C $(GNUEFI_DIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE)

# Create build directories (automatically create subdirectories as needed)
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# Create subdirectories in build/ to match src/ structure
$(BUILD_DIR)/%/:
	@mkdir -p $@

# Pattern rule for compiling C files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	@echo "CC    $<"
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

# Pattern rule for compiling assembly files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.S
	@mkdir -p $(dir $@)
	@echo "AS    $<"
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

# Link to create shared object (now uses all object files)
$(SO_TARGET): $(ALL_OBJ_FILES) $(GNUEFI_LIB_DIR)/libefi.a $(GNUEFI_GNUEFI_DIR)/libgnuefi.a | $(BUILD_DIR)
	@echo "LD    $@"
	$(LD) $(LDFLAGS) $(GNUEFI_CRT_OBJS) $(ALL_OBJ_FILES) -o $@ \
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
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR) esp
	@rm -f AAVMF_VARS_copy.fd
	@$(MAKE) -C $(GNUEFI_DIR) clean > /dev/null 2>&1 || true
	@echo "Clean completed"

# Show discovered source files (for debugging)
show-sources:
	@echo "Discovered source files:"
	@echo "C files:"
	@$(foreach file,$(SRC_C_FILES),echo "  $(file)";)
	@echo "Assembly files:"
	@$(foreach file,$(SRC_S_FILES),echo "  $(file)";)
	@echo "Header files:"
	@$(foreach file,$(SRC_H_FILES),echo "  $(file)";)
	@echo "Object files will be:"
	@$(foreach file,$(ALL_OBJ_FILES),echo "  $(file)";)
	@echo "Include directories:"
	@$(foreach dir,$(SRC_INCLUDE_DIRS),echo "  $(dir)";)

# Show build directories
show-dirs:
	@echo "Source directories:"
	@$(foreach dir,$(SRC_SUBDIRS),echo "  $(dir)";)

# Show help
help:
	@echo "RLOS Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all         - Build the EFI application (default)"
	@echo "  run         - Build and run with QEMU"
	@echo "  debug       - Build debug version"
	@echo "  clean       - Clean all build artifacts"
	@echo "  show-sources - Show all discovered source files"
	@echo "  show-dirs   - Show all discovered source directories"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Features:"
	@echo "  - Automatic source file discovery in src/"
	@echo "  - Supports C (.c), Assembly (.S), and Header (.h) files"
	@echo "  - Automatic header file include path generation"
	@echo "  - Preserves directory structure in build/"
	@echo "  - No manual Makefile updates needed for new files"
	@echo ""
	@echo "Requirements:"
	@echo "  - aarch64-linux-gnu-gcc toolchain"
	@echo "  - qemu-system-aarch64"
	@echo "  - qemu-efi-aarch64 (for UEFI firmware)"