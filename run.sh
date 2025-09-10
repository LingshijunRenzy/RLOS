#!/bin/bash

# RLOS - ARM64 Separated Build System Script
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="$(pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ESP_DIR="$PROJECT_DIR/esp"

QEMU_SYSTEM_AARCH64="qemu-system-aarch64"
UEFI_CODE_PATH="/usr/share/AAVMF/AAVMF_CODE.fd"
UEFI_VARS_PATH="/usr/share/AAVMF/AAVMF_VARS.fd"
LOCAL_VARS_PATH="./AAVMF_VARS_copy.fd"

print_banner() {
    echo -e "${BLUE}"
    echo "===================================="
    echo "         RLOS Boot Script         "
    echo "===================================="
    echo -e "${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    print_status "Checking dependencies..."
    
    if ! command -v $QEMU_SYSTEM_AARCH64 &> /dev/null; then
        print_error "QEMU ARM64 not found. Install with: sudo apt install qemu-system-arm"
        exit 1
    fi
    
    if [ ! -f "$UEFI_CODE_PATH" ]; then
        print_error "ARM64 UEFI firmware not found. Install with: sudo apt install qemu-efi-aarch64"
        exit 1
    fi
    
    if ! command -v aarch64-linux-gnu-gcc &> /dev/null; then
        print_error "ARM64 cross-compilation toolchain not found. Install with: sudo apt install gcc-aarch64-linux-gnu"
        exit 1
    fi
    
    print_status "Dependencies satisfied"
}

clean_build() {
    print_status "Cleaning build..."
    make clean > /dev/null 2>&1 || true
    rm -rf "$ESP_DIR" > /dev/null 2>&1 || true
    print_status "Clean completed"
}

build_system() {
    local build_mode="${1:-release}"
    
    print_status "Building system..."
    if make all; then
        print_status "Build successful"
    else
        print_error "Build failed"
        exit 1
    fi
    
    if [ ! -f "build/bootloader.efi" ]; then
        print_error "Bootloader EFI not created"
        exit 1
    fi
    
    if [ ! -f "build/kernel.elf" ]; then
        print_error "Kernel ELF not created"
        exit 1
    fi
    
    print_status "Generated files:"
    echo -e "${BLUE}Bootloader:${NC}"
    file build/bootloader.efi
    ls -lh build/bootloader.efi
    echo -e "${BLUE}Kernel:${NC}"
    file build/kernel.elf  
    ls -lh build/kernel.elf
}

setup_esp() {
    print_status "Setting up EFI System Partition..."
    
    mkdir -p "$ESP_DIR/EFI/BOOT"
    cp build/bootloader.efi "$ESP_DIR/EFI/BOOT/BOOTAA64.EFI"
    cp build/kernel.elf "$ESP_DIR/kernel.elf"
    
    print_status "ESP structure:"
    echo -e "${BLUE}ESP Directory:${NC}"
    find "$ESP_DIR" -type f -exec ls -lh {} \;
    
    print_status "ESP setup completed"
}

setup_uefi_vars() {
    if [ ! -f "$LOCAL_VARS_PATH" ]; then
        print_status "Copying UEFI variables..."
        cp "$UEFI_VARS_PATH" "$LOCAL_VARS_PATH"
    fi
}

start_qemu() {
    local mode="${1:-vnc}"
    
    case "$mode" in
        "console")
            start_qemu_console
            ;;
        # Removed debug case
        *)
            start_qemu_vnc
            ;;
    esac
}

start_qemu_console() {
    print_status "Starting QEMU (console)..."
    print_warning "Kernel output via UART. Ctrl+C to exit."
    
    $QEMU_SYSTEM_AARCH64 \
        -machine virt,gic-version=3 \
        -cpu cortex-a57 \
        -m 512 \
        -drive if=pflash,format=raw,file="$UEFI_CODE_PATH",readonly=on \
        -drive if=pflash,format=raw,file="$LOCAL_VARS_PATH" \
        -drive file=fat:rw:"$ESP_DIR",format=raw \
        -nographic
}

start_qemu_vnc() {
    print_status "Starting QEMU (VNC)..."
    print_warning "Connect VNC to localhost:5901 (password: 123456). Ctrl+C to exit."
    echo -e "${YELLOW}Starting QEMU in 3 seconds...${NC}"
    sleep 3
    
    {
        echo "change vnc password"
        echo "123456"
        echo ""
        sleep 1000000
    } | $QEMU_SYSTEM_AARCH64 \
        -machine virt,gic-version=3 \
        -cpu cortex-a57 \
        -m 512 \
        -drive if=pflash,format=raw,file="$UEFI_CODE_PATH",readonly=on \
        -drive if=pflash,format=raw,file="$LOCAL_VARS_PATH" \
        -drive file=fat:rw:"$ESP_DIR",format=raw \
        -vnc :1,password \
        -monitor stdio
}

main() {
    print_banner
    
    case "${1:-run}" in
        "clean")
            clean_build
            ;;
        "build")
            check_dependencies
            clean_build
            build_system
            ;;
        "run")
            check_dependencies
            clean_build
            build_system
            setup_esp
            setup_uefi_vars
            start_qemu vnc
            ;;
        "console"|"run-console")
            check_dependencies
            clean_build
            build_system
            setup_esp
            setup_uefi_vars
            start_qemu console
            ;;
        "test")
            check_dependencies
            clean_build
            build_system
            setup_esp
            setup_uefi_vars
            print_status "Running quick test (30 seconds)..."
            timeout 30 $QEMU_SYSTEM_AARCH64 \
                -machine virt,gic-version=3 \
                -cpu cortex-a57 \
                -m 512 \
                -drive if=pflash,format=raw,file="$UEFI_CODE_PATH",readonly=on \
                -drive if=pflash,format=raw,file="$LOCAL_VARS_PATH" \
                -drive file=fat:rw:"$ESP_DIR",format=raw \
                -nographic || true
            print_status "Test completed"
            ;;
        "help")
            echo "Usage: $0 [command]"
            echo "Commands:"
            echo "  run          - Build and run with VNC (default)"
            echo "  console      - Build and run with console output"
            echo "  test         - Quick 30-second test run"
            echo "  build        - Clean and build only"
            echo "  clean        - Clean build artifacts"
            echo "  help         - Show this help"
            echo ""
            echo "Architecture: UEFI bootloader loads bare-metal kernel."
            ;;
        *)
            print_error "Unknown command: $1"
            echo "Use '$0 help' for usage."
            exit 1
            ;;
    esac
}

main "$@"
