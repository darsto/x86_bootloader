#![no_std]
#![no_main]

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn _start() -> ! {
    let vga_buffer = 0xb8000 as *mut u8;
    let hello_msg = b"Hello Rust !";

    for (i, &byte) in hello_msg.iter().enumerate() {
        unsafe {
            *vga_buffer.add(i * 2) = byte;
            *vga_buffer.add(i * 2 + 1) = 0xb;
        }
    }

    loop {
        continue
    }
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {
        continue
    }
}
