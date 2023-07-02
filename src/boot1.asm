[bits 16]    ; 16-bit Real Mode.
[org 0x7c00] ; x86 BIOS loads us here

_boot:
    ; sane init
    cld ; clear direction flag, i.e. make lodsb always *increment* the si
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov sp, 0x7c00 ; use the rest of lower memory for stack (... - 0x7c00)
    mov bp, sp

    ; clear the screen (by setting video mode)
    mov al, 0x3 ; 0x3 => text mode. 80x25. 16 colors. 8 pages.
    mov ah, 0
    int 0x10

    ; say hello
    mov si, boot1_hello_msg
    call print
    hlt ; wait for the print to finish, in case anything goes wrong later

    ; load stage 2 bootloader and kernel from the current disk
    ; it should land right after the stage 1 bootloader, (0x7c00+0x200 - ...)
    ; we're limited to roughly 637KB, up to 0x9fc00 (Extended BIOS Data Area)
    mov si, 1 ; start reading from the first sector
    mov cx, (kernel_end - boot1_end) / 512 ; num of sectors to read
    mov di, boot2_start ; address (in current seg) to read into
    call disk_read

    jmp _boot2_init
done:
    jmp hlt


; print a null-terminated string
;   input: si - string
;   output: si clobbered
print:
    push ax
    mov ah, 0x0e ; param for int 0x10; 0x0e => "teletype output"
.print_char:
    lodsb ; load si into al; increment si
    cmp al, 0
    je .print_done
    int 0x10
    jmp .print_char
.print_done:
    pop ax
    ret
disk db 0x80


; read from disk
;  input: dl - disk index
;         si - sector to start reading from (LBA)
;         cx - number of sectors to read
;         es:di - destination address
;  output: si, cx, es, di clobbered
disk_read:
    ; split into reads that do not cross the segment boundary
    mov ax, di
    ; find max sector count to read at once
    neg ax
    sar ax, 9  ; bx /= 512
    ; safely assume ax > 0
    cmp cx, ax
    jle .read_one;
    mov ax, cx ; override with the safe maximum
.setup_first:
    mov [dap.src_sector], si
    mov [dap.num_sectors], ax
    mov [dap.dst_address], di
    mov [dap.dst_address + 2], es
.read_one:
    mov bx, si ; backup the source LBA
    mov si, dap
    mov ah, 0x42
    int 0x13
    jc .disk_error
    mov si, bx  ; restore the source LBA
    sub cx, [dap.num_sectors]  ; subtract what we just read
    test cx, cx
    jle .done ; return if everything's read
.setup_next:
    ; advance dap.src_sector
    add bx, [dap.num_sectors]
    mov [dap.src_sector], bx

    ; advance dap.dst_address + 2
    mov bx, es
    inc bx
    mov [dap.dst_address + 2], bx

    ; setup dap.dst_address
    mov bx, 0
    mov [dap.dst_address], bx

    ; setup dap.num_sectors
    mov ax, cx
    and ax, 0x7F
    mov [dap.num_sectors], ax
    jmp .read_one
.done:
    ret
.disk_error:
    mov si, disk_error_msg
    call print
    jmp hlt


; halt the system indefinitely
hlt:
    hlt
    jmp hlt


boot1_hello_msg: db "Boot Stage 1",13,10,0
disk_error_msg: db "Failed to read disk",13,10,0


; Disk Access Packet for INT 0x13 AH=0x42: Extended Read Sectors From Drive
dap:
    db 0x10                ; size of dap in bytes, always 0x10
    db 0                   ; unused; always 0
.num_sectors:
    dw 0x0  ; number of sectors (512b) to read (max 127 on some BIOSes)
.dst_address:
    dd 0x0  ; segment:offset address of the destination address
.src_sector:
    dq 0x0  ; sector to start reading from (LBA)


times 510-($-$$) db 0 ; padding
dw 0xaa55 ; magic footer for BIOS
