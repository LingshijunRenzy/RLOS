[org 0x7c00]
[bits 16]

start:
    ; --- Setup Segments ---
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; --- Read Bootloader from Disk ---
    ; Using INT 13h, AH=42h (Extended Read)
    ; Load 16 sectors from LBA 1 to 0x8000
    mov si, dap
    mov ah, 0x42
    mov dl, 0x80 ; Drive 0 (first HDD)
    int 0x13
    jc .disk_error

    ; --- Jump to Bootloader ---
    jmp 0x0000:0x8000

.disk_error:
    mov si, disk_error_msg
.print_loop:
    lodsb
    cmp al, 0
    je .halt
    mov ah, 0x0e
    mov bh, 0
    int 0x10
    jmp .print_loop

.halt:
    cli
    hlt

; Disk Address Packet (DAP)
dap:
    db 0x10 ; size of packet
    db 0    ; reserved
    dw 64   ; sectors to read (increase to load full bootloader)
    dw 0x8000 ; destination offset
    dw 0x0000 ; destination segment
    dq 1    ; LBA start (bootloader begins at sector 1)

disk_error_msg db 'Disk read error!', 0

times 510 - ($ - $$) db 0
dw 0xaa55