[bits 16]    ; 16-bit Real Mode.

_boot2_init:
    ; say hello
    mov si, boot2_hello_msg
    call print
    hlt ; wait for the print to finish, in case anything goes wrong later

    call check_a20
    test ax, ax
    jz .error_a20 ; we could try to enable A20, but SeaBIOS seems to always
                  ; have it enabled - just abort if somehow it's not

    mov edi, 0x1000 ; page table at (0x1000 - 0x4000)
    call setup_page_tables

    lgdt [gdt64_desc] ; dummy 64-bit segmentation

    call setup_pic

    ; we're already in 32-bit compatibility mode
    ; setup the registers, then go 64-bit
    cli
    mov ax, gdt64.data
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    ; doing the long jmp will switch to 64-bit
    jmp gdt64.code:kernel_start

.error_a20:
    mov si, a20_disabled_message
    call print
    jmp hlt


; check if a20 line is enabled
;  output: ax - 1 if a20 is enabled, otherwise 0
;          all registers clobbered
check_a20:
    push bp
    mov bp, sp

    mov ax, 0
    mov es, ax ; es = 0
    not ax
    mov fs, ax ; fs = 0xFFFF

    ; pick two memory addresses offset by 16 bytes (1 segment)
    sub sp, 0x2
    mov di, sp
    sub sp, 0x10
    mov si, sp

    mov byte [es:di], 0x00 ; write to 0000:bp-2
    mov ah, [fs:si] ; backup the memory at FFFF:bp-12
    mov byte [fs:si], 0xFF ; write to FFFF:bp-12
                           ; if the A20 is disabled, the above address will overflow
                           ; and effectively write to [es:di]. If A20 is enabled, it
                           ; will write to a 21-bit address - 0x10XXXX
    mov [fs:si], ah ; whatever the result, restore the previous contents of that memory
    add sp, 0x12

    cmp byte [es:di], 0xFF
    mov ax, 0
    je .ret

    mov ax, 1 ; A20 enabled.
.ret:
    pop bp
    ret


; init page tables as needed by x86_64
; we'll setup 512 of 2MB hugepages
;  input: edi - pointer to place page tables at
;  output: all registers clobbered
setup_page_tables:
    ; Start by zeroing the P4
    push edi
    mov ecx, 0x1000
    xor eax, eax
    rep stosd
    pop edi

    ; Setup first entry of P4 -> P3
    lea eax, [edi + 0x1000]
    or eax, 0b11
    mov [edi], eax

    ; Setup first entry of P3 -> P2
    lea eax, [edi + 0x2000]
    or eax, 0b11
    mov [edi + 0x1000], eax

    ; Begin setting up P2 entries
    mov esi, edi ; backup edi
    lea edi, [edi + 0x2000]

    mov eax, 0x0 | 0b10000011 ; start the mapping at 0x0, PRESENT | WRITABLE | HUGE
    mov ecx, 512  ; map 512 hugepages
.init_one_p2:
    mov [edi], eax
    add eax, 0x200000 ; advance the page offset
    add edi, 8        ; advance the P2 entry offset
    loop .init_one_p2

    mov edi, esi ; restore edi

    ; Store the Page Table
    mov cr3, edi

    ; Enable PAE
    mov eax, cr4
    mov eax, (1 << 5) | (1 << 7)
    mov cr4, eax

    ; Set the Long Mode bit
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Enable Paging
    mov eax, cr0
    or eax, (1 << 31) | (1 << 0)
    mov cr0, eax

    ret


; Setup Programmable Interrupt Controller
; Remap physical IRQ vectors so they don't conflict with the long mode exception
; vectors (<= 0x1f). We'll put them at vectors 0x20+. All of them will be masked.
;  output: al clobbered
setup_pic:
    ; Restart PICs
    mov al, 0x11 ; init + set 8086/88 mode later on
    out pic1.cmd, al
    out pic2.cmd, al

    ; Map PIC1 to vectors 0x20+
    mov al, 0x20
    out pic1.dat, al

    ; Map PIC2 to vectors 0x28+
    mov al, 0x28
    out pic2.dat, al

    ; Setup cascading
    mov al, (1 << 2) ; PIC2 at IRQ2
    out pic1.dat, al
    mov al, 2 ; Tell PIC2 they're a slave connected to master's IRQ2
    out pic2.dat, al

    mov al, 0x1  ; Set the normal 8086/88 mode
    out pic1.dat, al
    out pic2.dat, al

    ; Mask all IRQs
    mov al, 0xFF
    out pic1.dat, al
    out pic2.dat, al

    ret


%define SEG_CODE_READABLE      (1 << 41)
%define SEG_DATA_WRITABLE      (1 << 41)
%define SEG_DATA_GROWDOWN      (1 << 42)
%define SEG_CODE_LOW_PRIVILEGE (1 << 42)
%define SEG_EXECUTABLE         (1 << 43)
%define SEG_NONSYSTEM          (1 << 44)
%define SEG_REQ_PRIVILEGE_0    (0 << 45)
%define SEG_REQ_PRIVILEGE_1    (1 << 45)
%define SEG_REQ_PRIVILEGE_2    (2 << 45)
%define SEG_REQ_PRIVILEGE_3    (3 << 45)
%define SEG_PRESENT            (1 << 47)
%define SEG_LONG_CODE          (1 << 53)
%define SEG_PROTECTED          (1 << 54)


gdt64:
.null: equ $ - gdt64
    dq 0x0
.code: equ $ - gdt64
    dq SEG_LONG_CODE | SEG_PRESENT | SEG_REQ_PRIVILEGE_0 | SEG_NONSYSTEM | \
       SEG_EXECUTABLE | SEG_CODE_READABLE
.data: equ $ - gdt64
    dq SEG_PRESENT | SEG_REQ_PRIVILEGE_0 | SEG_NONSYSTEM | SEG_CODE_READABLE
.end:


gdt64_desc:
    dw gdt64.end - gdt64 - 1
    dq gdt64


pic1:
.cmd: equ 0x20
.dat: equ 0x21
pic2:
.cmd: equ 0xA0
.dat: equ 0xA1


boot2_hello_msg: db "Boot Stage 2",13,10,0
a20_disabled_message: db 'A20 is disabled. Aborting.',13,10,0
