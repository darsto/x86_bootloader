boot1_start:
    %include "boot1.asm"
boot1_end:

boot2_start:
    %include "boot2.asm"
    align 512, db 0
boot2_end:

kernel_start:
    incbin "kernel.bin"
    align 512, db 0
kernel_end: