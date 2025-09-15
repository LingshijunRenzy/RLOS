ENTRY(_start)

KERNEL_VIRT_BASE = 0xFFFF800000000000;

SECTIONS
{
    . = 0x0;

    .text : {
        _stext = .;
        *(.text.entry)
        *(.text*)
        _etext = .;
    }

    .rodata : {
        _srodata = .;
        *(.rodata*)
        _erodata = .;
     }

    .data : {
        _sdata = .;
        *(.data*)
        _edata = .;
    }

    .bss : {
        _sbss = .;
        *(.bss*)
        _ebss = .;

        /* Initial kernel stack */
        . = ALIGN(16);
        _init_stack = .;
        . += 0x10000;  /* 64KB stack */
        _init_stack_top = .;
    }

    _kernel_virt_start = KERNEL_VIRT_BASE;
    _kernel_size = _ebss - _stext;
}
