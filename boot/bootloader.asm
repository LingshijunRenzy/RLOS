org 0x8000
bits 16

start:
    ; We are now at 0x8000, loaded by the MBR.
    ; CS should be 0x0000, IP should be 0x8000.
    ; Let's set up our segments properly.
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    ; Set stack pointer below our code
    mov sp, 0x8000

    ; --- Print welcome message ---
    mov si, bootloader_welcome_msg
    call print_string_16

    ; --- Switch to protected mode ---
    cli
    ; Mask all PIC interrupts
    mov al, 0xFF
    out 0x21, al
    out 0xA1, al

    ; Load GDT and IDT
    lgdt [gdt_descriptor]
    lidt [idt_descriptor]

    ; Enable protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far jump to flush instruction pipeline
    jmp 0x08:protected_mode_start

; --- 16-bit functions ---
print_string_16:
    mov ah, 0x0e
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    ret

; === 32-bit Protected Mode ===
bits 32
protected_mode_start:
    mov ax, 0x10 ; Data segment selector
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000 ; Set up stack high in memory

    call check_long_mode_support
    call setup_paging

    ; Enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Reload CR3 after enabling PAE
    mov eax, pml4_table
    mov cr3, eax

    ; Enable Long Mode (EFER.LME)
    mov ecx, 0xc0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Enable Paging (CR0.PG)
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ; Far jump to 64-bit code
    jmp 0x18:long_mode_64

check_long_mode_support:
    ; (Code is fine, no changes needed)
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 1 << 21
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd
    cmp eax, ecx
    je .no_long_mode
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29
    jz .no_long_mode
    ret
.no_long_mode:
    mov si, check_lm_fail_msg
    ; Can't use 16-bit print, halt for now
    cli
    hlt

setup_paging:
    ; Zero out page tables
    mov edi, pml4_table
    mov ecx, 4096 * 4 / 4 ; 4 tables, 4KB each, clearing DWORDs
    xor eax, eax
    rep stosd

    ; Map the first 2MB of physical memory
    ; PML4[0] -> PDPT
    mov dword [pml4_table], pdpt_table + 3
    ; PDPT[0] -> PDT
    mov dword [pdpt_table], pdt_table + 3
    ; PDT[0] -> 2MB page at 0x0
    mov dword [pdt_table], 0x00000083 ; 2MB page, present, r/w
    ret

; === 64-bit Long Mode ===
bits 64
print_string_64:
    ; (Code is fine, but needs a start address for VGA buffer)
    mov rdi, 0xb8000
.loop:
    mov cl, [rsi]
    inc rsi
    cmp cl, 0
    je .done
    cmp cl, 10
    je .newline
    cmp cl, 13
    je .cr
    mov ch, 0x0f
    mov [rdi], cx
    add rdi, 2
    jmp .loop
.cr:
    mov rax, rdi
    sub rax, 0xb8000
    mov rbx, 160
    xor rdx, rdx
    div rbx
    sub rdi, rdx
    jmp .loop
.newline:
    mov rax, rdi
    sub rax, 0xb8000
    mov rbx, 160
    xor rdx, rdx
    div rbx
    sub rdi, rdx
    add rdi, 160
    jmp .loop
.done:
    ret

long_mode_64:
    mov ax, 0x20 ; 64-bit data segment
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x200000 ; Stack in mapped memory

    mov rsi, success_msg
    call print_string_64

.halt:
    cli
    hlt
    jmp .halt

; === Data and Tables ===
bits 16
align 16
gdt_start:
    dq 0 ; Null descriptor
    ; 32-bit Code Segment
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x9A ; P, DPL=0, S, Code, R/E
    db 0xCF ; G, D=1, L=0, AVL, Limit
    db 0x00
    ; 32-bit Data Segment
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92 ; P, DPL=0, S, Data, R/W
    db 0xCF ; G, D=1, L=0, AVL, Limit
    db 0x00
    ; 64-bit Code Segment
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x9A ; P, DPL=0, S, Code, R/E
    db 0xAF ; G, D=0, L=1, AVL, Limit
    db 0x00
    ; 64-bit Data Segment
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92 ; P, DPL=0, S, Data, R/W
    db 0xCF ; G, D=1, L=0, AVL, Limit
    db 0x00
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dq gdt_start

align 16
idt_start:
    ; 256 entries for a simple halt handler
    %rep 256
        dw handler32
        dw 0x08
        db 0
        db 0x8E ; P, DPL=0, Interrupt Gate
        dw 0
    %endrep
idt_end:

idt_descriptor:
    dw idt_end - idt_start - 1
    dq idt_start

bootloader_welcome_msg db 'Bootloader loaded at 0x8000', 13, 10, 0
success_msg db 'Successfully switched to 64-bit long mode!', 13, 10, 0
check_lm_fail_msg db 'Long Mode not supported. Halting.', 0

; Aligned page tables
align 4096
pml4_table:
    times 512 dq 0
pdpt_table:
    times 512 dq 0
pdt_table:
    times 512 dq 0

bits 32
handler32:
    cli
    hlt