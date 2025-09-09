#include "kernel.h"

// QEMU ARM64 virt machine UART0 (PL011) base address
#define UART0_BASE    0x09000000
#define UART0_DR      (UART0_BASE + 0x00)  // Data register
#define UART0_FR      (UART0_BASE + 0x18)  // Flag register
#define UART0_IBRD    (UART0_BASE + 0x24)  // Integer baud rate divisor
#define UART0_FBRD    (UART0_BASE + 0x28)  // Fractional baud rate divisor
#define UART0_LCRH    (UART0_BASE + 0x2C)  // Line control register
#define UART0_CR      (UART0_BASE + 0x30)  // Control register

// UART Flag register bits
#define UART_FR_TXFF  (1 << 5)  // Transmit FIFO full

// Basic memory-mapped I/O functions
static inline void mmio_write32(unsigned long addr, unsigned int value) {
    *(volatile unsigned int*)addr = value;
}

static inline unsigned int mmio_read32(unsigned long addr) {
    return *(volatile unsigned int*)addr;
}

// Initialize UART for output
void uart_init(void) {
    // Disable UART
    mmio_write32(UART0_CR, 0);
    
    // Set baud rate to 115200 (assuming 24MHz clock)
    // IBRD = 24000000 / (16 * 115200) = 13
    // FBRD = int((0.020833... * 64) + 0.5) = 1
    mmio_write32(UART0_IBRD, 13);
    mmio_write32(UART0_FBRD, 1);
    
    // Set line control: 8 bits, no parity, 1 stop bit, FIFOs enabled
    mmio_write32(UART0_LCRH, (3 << 5) | (1 << 4));
    
    // Enable UART, TX and RX
    mmio_write32(UART0_CR, (1 << 0) | (1 << 8) | (1 << 9));
}

// Send a single character
void uart_putc(char c) {
    // Wait until TX FIFO is not full
    while (mmio_read32(UART0_FR) & UART_FR_TXFF);
    
    // Write character to data register
    mmio_write32(UART0_DR, c);
}

// Send a string
void uart_puts(const char* str) {
    while (*str) {
        if (*str == '\n') {
            uart_putc('\r');  // Add carriage return before newline
        }
        uart_putc(*str++);
    }
}

// Simple hex to string conversion
void uart_put_hex(unsigned long value) {
    const char hex_chars[] = "0123456789ABCDEF";
    uart_puts("0x");
    
    for (int i = 60; i >= 0; i -= 4) {
        uart_putc(hex_chars[(value >> i) & 0xF]);
    }
}

// Simple decimal to string conversion  
void uart_put_dec(unsigned long value) {
    if (value == 0) {
        uart_putc('0');
        return;
    }
    
    char buffer[32];
    int pos = 0;
    
    while (value > 0) {
        buffer[pos++] = '0' + (value % 10);
        value /= 10;
    }
    
    // Print in reverse order
    for (int i = pos - 1; i >= 0; i--) {
        uart_putc(buffer[i]);
    }
}

// ARM64 kernel entry point - called by bootloader
void _start(void) {
    // Initialize UART first for output
    uart_init();
    
    // Call main kernel function
    kernel_main(0);
    
    // Kernel should never return, but if it does, halt
    while(1) {
        __asm__ volatile("wfe");  // Wait for event (low power)
    }
}

void kernel_main(void* memory_map){
    // Mark parameter as used to avoid compiler warning
    (void)memory_map;
    
    // Print kernel startup banner
    uart_puts("\n");
    uart_puts("==============================================\n");
    uart_puts("  ____  _     ___  ____                       \n");
    uart_puts(" |  _ \\| |   / _ \\/ ___|                    \n");
    uart_puts(" | |_) | |  | | | \\___ \\                    \n");
    uart_puts(" |  _ <| |__| |_| |___) |                     \n");
    uart_puts(" |_| \\_\\_____\\___/|____/                   \n");
    uart_puts("                                              \n");
    uart_puts("==============================================\n");
    uart_puts("\n");
    
    // Print system information
    uart_puts("System Information:\n");
    uart_puts("  Architecture: ARM64\n");
    uart_puts("  Environment: Bare Metal\n");
    uart_puts("  Memory Map Address: ");
    uart_put_hex((unsigned long)memory_map);
    uart_puts("\n");
    uart_puts("\n");
    
    // Get current time - not available in bare metal, show placeholder
    uart_puts("  Current Time: [Not available in bare metal mode]\n");
    
    uart_puts("\n");
    uart_puts("Kernel initialization completed successfully!\n");
    uart_puts("RLOS is now running...\n");
    uart_puts("\n");
    uart_puts("System Status: ACTIVE\n");
    uart_puts("Kernel Mode: Bare Metal\n");
    uart_puts("Boot Services: Unavailable (Exited)\n");
    uart_puts("\n");
    uart_puts("=== RLOS Kernel Main Loop Started ===\n");
    uart_puts("(Press Ctrl+C or close QEMU to exit)\n");
    uart_puts("\n");
    
    while(1) {    
        // In a real kernel, this is where we would:
        // - Handle interrupts
        // - Process scheduler
        // - Memory management
        // - I/O operations
        // - System calls
    }
}