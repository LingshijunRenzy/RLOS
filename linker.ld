/* Linker script for RLOS kernel */
OUTPUT_FORMAT(elf64-x86-64)
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start)

SECTIONS
{
    . = 1M; /* load at 1 MiB */

    kernel_start = .;

    .multiboot_header ALIGN(8) : { *(.multiboot_header) }
    .text ALIGN(16) : { *(.text*) }
    .rodata ALIGN(16) : { *(.rodata*) }
    .data ALIGN(16) : { *(.data*) }
    .bss ALIGN(16) : {
        bss_start = .;
        *(.bss*)
        *(COMMON)
        bss_end = .;
    }

    kernel_end = .;
}
