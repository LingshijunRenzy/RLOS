#!/bin/bash

#==============================================================================
# RLOS - ARM64 Separated Bootloader + Kernel System
# 
# This script builds and runs the RLOS ARM64 system with separated:
# - UEFI Bootloader (bootloader.efi)
# - Bare Metal Kernel (kernel.elf)
# Author: RLOS Development Team
# License: MIT
#==============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project directories
PROJECT_DIR="$(pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ESP_DIR="$PROJECT_DIR/esp"

# QEMU and UEFI firmware paths
QEMU_SYSTEM_AARCH64="qemu-system-aarch64"
UEFI_CODE_PATH="/usr/share/AAVMF/AAVMF_CODE.fd"
UEFI_VARS_PATH="/usr/share/AAVMF/AAVMF_VARS.fd"
LOCAL_VARS_PATH="./AAVMF_VARS_copy.fd"

print_banner() {
    echo -e "${BLUE}"
    echo "=================================================================="
    echo "                     RLOS Boot Script"
    echo "        ARM64 Separated Bootloader + Kernel System"
    echo "=================================================================="
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
    
    # Check for QEMU
    if ! command -v $QEMU_SYSTEM_AARCH64 &> /dev/null; then
        print_error "QEMU ARM64 not found. Install with:"
        echo "  sudo apt install qemu-system-arm"
        exit 1
    fi
    
    # Check for ARM64 UEFI firmware
    if [ ! -f "$UEFI_CODE_PATH" ]; then
        print_error "ARM64 UEFI firmware not found. Install with:"
        echo "  sudo apt install qemu-efi-aarch64"
        exit 1
    fi
    
    # Check for cross-compilation toolchain
    if ! command -v aarch64-linux-gnu-gcc &> /dev/null; then
        print_error "ARM64 cross-compilation toolchain not found. Install with:"
        echo "  sudo apt install gcc-aarch64-linux-gnu"
        exit 1
    fi
    
    print_status "All dependencies satisfied"
}

clean_build() {
    print_status "Cleaning previous build..."
    make clean > /dev/null 2>&1 || true
    rm -rf "$ESP_DIR" > /dev/null 2>&1 || true
    print_status "Clean completed"
}

build_system() {
    print_status "Building RLOS separated system..."
    
    if make all; then
        print_status "Build successful"
    else
        print_error "Build failed"
        exit 1
    fi
    
    # Verify the bootloader and kernel files were created
    if [ ! -f "build/bootloader.efi" ]; then
        print_error "Bootloader EFI file not created"
        exit 1
    fi
    
    if [ ! -f "build/kernel.elf" ]; then
        print_error "Kernel ELF file not created"
        exit 1
    fi
    
    # Show file info
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
    
    # Create ESP directory structure
    mkdir -p "$ESP_DIR/EFI/BOOT"
    
    # Copy the bootloader EFI application
    cp build/bootloader.efi "$ESP_DIR/EFI/BOOT/BOOTAA64.EFI"
    
    # Copy the kernel ELF file to ESP root
    cp build/kernel.elf "$ESP_DIR/kernel.elf"
    
    # Show ESP structure
    print_status "ESP structure:"
    echo -e "${BLUE}ESP Directory:${NC}"
    find "$ESP_DIR" -type f -exec ls -lh {} \;
    
    print_status "ESP setup completed"
}

setup_uefi_vars() {
    # Copy UEFI variables if not exists
    if [ ! -f "$LOCAL_VARS_PATH" ]; then
        print_status "Copying UEFI variables..."
        cp "$UEFI_VARS_PATH" "$LOCAL_VARS_PATH"
    fi
}

start_qemu() {
    local mode="${1:-vnc}"
    
    if [ "$mode" = "console" ]; then
        start_qemu_console
    else
        start_qemu_vnc
    fi
}

start_qemu_console() {
    print_status "Starting QEMU with console output..."
    print_warning "Bootloader will load kernel.elf and jump to bare metal kernel"
    print_warning "Kernel will show UART output and run in main loop with heartbeat"
    print_warning "Use Ctrl+C to exit QEMU"
    echo ""
    
    print_status "Starting QEMU..."
    
    # Launch QEMU with console output
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
    print_status "Starting QEMU with VNC output..."
    print_warning "Bootloader will load kernel.elf and jump to bare metal kernel"
    print_warning "Connect to VNC at localhost:5901 with password: 123456"
    print_warning "Use Ctrl+C in this terminal to exit QEMU"
    echo ""
    echo -e "${BLUE}QEMU Command:${NC}"
    echo "qemu-system-aarch64 \\"
    echo "  -machine virt,gic-version=3 \\"
    echo "  -cpu cortex-a57 \\"
    echo "  -m 512 \\"
    echo "  -drive if=pflash,format=raw,file=$UEFI_CODE_PATH,readonly=on \\"
    echo "  -drive if=pflash,format=raw,file=$LOCAL_VARS_PATH \\"
    echo "  -drive file=fat:rw:$ESP_DIR,format=raw \\"
    echo "  -vnc :1,password \\"
    echo "  -monitor stdio"
    echo ""
    echo -e "${GREEN}VNC Connection Details:${NC}"
    echo "  Address: localhost:5901"
    echo "  Password: 123456"
    echo "  VNC Clients: vncviewer, remmina, etc."
    echo ""
    
    # Give user a moment to read
    sleep 3
    
    print_status "Starting QEMU... You can now connect via VNC"
    
    # Launch QEMU with VNC and monitor
    {
        echo "change vnc password"
        echo "123456"
        echo ""
        sleep 1000000  # Keep feeding empty commands to monitor
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

# Main execution
main() {
    print_banner
    
    # Parse command line arguments
    case "${1:-run}" in
        "clean")
            clean_build
            print_status "Clean completed"
            ;;
        "build")
            check_dependencies
            clean_build
            build_system
            print_status "Build completed"
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
            echo ""
            echo "Commands:"
            echo "  run         - Clean, build and run with VNC (default)"
            echo "  console     - Clean, build and run with console output"
            echo "  test        - Quick 30-second test run"
            echo "  build       - Clean and build only"
            echo "  clean       - Clean build artifacts"
            echo "  help        - Show this help"
            echo ""
            echo "System Architecture:"
            echo "  - UEFI Bootloader (bootloader.efi) loads kernel.elf"
            echo "  - Bare Metal Kernel (kernel.elf) runs with UART output"
            echo "  - Separated build system for clean architecture"
            ;;
        *)
            print_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"
