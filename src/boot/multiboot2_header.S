/* multiboot2 header for RLOS */
/* Reference: Multiboot2 spec */

.set ALIGN,    1
.set MBI_TAG_ALIGN, 8
.set HEADER_MAGIC, 0xE85250D6
.set ARCH, 0            /* 0 for i386 (works for x86_64 GRUB load) */

/* We'll let the linker fill in the length; we compute checksum = -(magic + arch + length) */

.section .multiboot_header,"a"
.align 8

multiboot2_header_start:
    .long HEADER_MAGIC        /* magic */
    .long ARCH                /* architecture */
    .long multiboot2_header_end - multiboot2_header_start /* total length */
    .long -(HEADER_MAGIC + ARCH + (multiboot2_header_end - multiboot2_header_start)) /* checksum */

    /* End tag */
    .word 0    /* type */
    .word 0    /* flags */
    .long 8    /* size of this tag */
multiboot2_header_end:

.global _start
.type _start, @function
_start:
    /* GRUB loads in 32-bit protected mode; we need a 32->64 transition.
       For simplicity in early phase, we rely on -m32? Actually we compile x86_64.
       Simpler path: we ask GRUB to load our 64-bit ELF; GRUB will enter 64-bit long mode
       if the ELF header is x86_64. In this scenario, _start is executed in long mode.
         So we just call kernel_main. */

    .extern kernel_main
     call kernel_main

.hang:
    hlt
    jmp .hang
