ENTRY(_start)
SECTIONS
{
    . = 0x40080000;
    
    .text : {
        *(.text*)
    }
    
    .rodata : {
        *(.rodata*)
    }
    
    .data : {
        *(.data*)
    }
    
    .bss : {
        *(.bss*)
        
        /* Initial kernel stack */
        . = ALIGN(16);
        _init_stack = .;
        . += 0x10000;  /* 64KB stack */
        _init_stack_top = .;
    }
}
