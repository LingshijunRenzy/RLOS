#include "kernel.h"
#include "boot_info.h"

#define UART0_BASE    0x09000000
#define UART0_DR      (UART0_BASE + 0x00)
#define UART0_FR      (UART0_BASE + 0x18)
#define UART0_IBRD    (UART0_BASE + 0x24)
#define UART0_FBRD    (UART0_BASE + 0x28)
#define UART0_LCRH    (UART0_BASE + 0x2C)
#define UART0_CR      (UART0_BASE + 0x30)

#define UART_FR_TXFF  (1 << 5)

static inline void mmio_write32(unsigned long addr, unsigned int value) {
    *(volatile unsigned int*)addr = value;
}

static inline unsigned int mmio_read32(unsigned long addr) {
    return *(volatile unsigned int*)addr;
}

void uart_init(void) {
    mmio_write32(UART0_CR, 0);
    
    mmio_write32(UART0_IBRD, 13);
    mmio_write32(UART0_FBRD, 1);
    
    mmio_write32(UART0_LCRH, (3 << 5) | (1 << 4));
    
    mmio_write32(UART0_CR, (1 << 0) | (1 << 8) | (1 << 9));
}

void uart_putc(char c) {
    while (mmio_read32(UART0_FR) & UART_FR_TXFF);
    
    mmio_write32(UART0_DR, c);
}

void uart_puts(const char* str) {
    while (*str) {
        if (*str == '\n') {
            uart_putc('\r');
        }
        uart_putc(*str++);
    }
}

void uart_put_hex(unsigned long value) {
    const char hex_chars[] = "0123456789ABCDEF";
    uart_puts("0x");
    
    for (int i = 60; i >= 0; i -= 4) {
        uart_putc(hex_chars[(value >> i) & 0xF]);
    }
}

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
    
    for (int i = pos - 1; i >= 0; i--) {
        uart_putc(buffer[i]);
    }
}

void _start(void) {
    boot_info_t* boot_info;
    
    __asm__ volatile ("mov %0, x0" : "=r" (boot_info));
    
    uart_init();
    
    uart_puts("Kernel Physical Load Info:\n");
    uart_puts("  Physical Base: ");
    uart_put_hex(boot_info->kernel_info.physical_base);
    uart_puts("\n  Entry Offset: ");
    uart_put_hex(boot_info->kernel_info.entry_offset);
    uart_puts("\n  Kernel Size: ");
    uart_put_hex(boot_info->kernel_info.size);
    uart_puts("\n  Segments Count: ");
    uart_put_dec(boot_info->kernel_info.segments_count);
    uart_puts("\n");
    
    extern char _init_stack_top[];
    uint64_t stack_offset = (uint64_t)_init_stack_top - 0;
    uint64_t stack_physical = boot_info->kernel_info.physical_base + stack_offset;
    
    uart_puts("  Stack Physical: ");
    uart_put_hex(stack_physical);
    uart_puts("\n\n");
    
    // TODO: 在这里可以设置MMU，建立虚拟内存映射
    // 将物理地址映射到高地址空间 (0xFFFF800000000000+)
    
    __asm__ volatile ("mov sp, %0" :: "r" (stack_physical) : "memory");
    
    kernel_main(boot_info);
    
    while(1) {
        __asm__ volatile("wfe");
    }
}

void kernel_main(boot_info_t* boot_info){
    (void)boot_info;
    
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
    
    uart_puts("System Information:\n");
    uart_puts("  Architecture: ARM64\n");
    uart_puts("  Environment: Bare Metal (Dynamic Load)\n");
    uart_puts("  Boot Info Address: ");
    uart_put_hex((unsigned long)boot_info);
    uart_puts("\n");
    uart_puts("  Kernel Physical Base: ");
    uart_put_hex(boot_info->kernel_info.physical_base);
    uart_puts("\n");
    uart_puts("  Kernel Size: ");
    uart_put_hex(boot_info->kernel_info.size);
    uart_puts("\n");
    if (boot_info && boot_info->memory_map_base) {
        uart_puts("  Memory Map Address: ");
        uart_put_hex((unsigned long)boot_info->memory_map_base);
        uart_puts("\n");
        uart_puts("  Memory Descriptors: ");
        uart_put_dec(boot_info->memory_map_desc_count);
        uart_puts("\n");
    }
    uart_puts("\n");
    
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
    }
}