[bits 64]

global _start
extern kernel_main

section .text
_start:
    ; Call the C function
    call kernel_main

    ; If kernel_main returns, halt the CPU
halt:
    hlt
    jmp halt