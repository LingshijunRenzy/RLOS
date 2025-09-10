ENTRY(_start)
MEMORY
{
    KERNEL_VMA : ORIGIN = 0xFFFF000040080000, LENGTH = 0x10000000
    KERNEL_LMA : ORIGIN = 0x40080000, LENGTH = 0x10000000
}

SECTIONS
{
    . = ORIGIN(KERNEL_VMA);

    .text : {
        _stext = .;
        *(.text.entry)
        *(.text*)
        _etext = .;
    } > KERNEL_VMA AT > KERNEL_LMA

    .rodata : {
        _srodata = .;
        *(.rodata*)
        _erodata = .;
    } > KERNEL_VMA AT > KERNEL_LMA

    .data : {
        _sdata = .;
        *(.data*)
        _edata = .;
    } > KERNEL_VMA AT > KERNEL_LMA

    .bss : {
        _sbss = .;
        *(.bss*)
        _ebss = .;

        /* Initial kernel stack */
        . = ALIGN(16);
        _init_stack = .;
        . += 0x10000;  /* 64KB stack */
        _init_stack_top = .;
    } > KERNEL_VMA AT > KERNEL_LMA

    _kernel_virt_start = ORIGIN(KERNEL_VMA);
    _kernel_phys_start = ORIGIN(KERNEL_LMA);
    _kernel_size = _ebss - _stext;
}
