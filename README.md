# Simple x86_64 bootloader + Rust Kernel

A minimal bootstrapper to run baremetal Rust on x86_64. Built with NASM and stable Rust toolchain.
The bootloader doesn't perform various necessary checks and shouldn't be used outside a VM.

The ASM was mostly based on articles from https://wiki.osdev.org (CC0-licensed).

# Build

```bash
$ rustup target add x86_64-unknown-none
$ make
```

# Run in QEMU
```bash
$ make run
qemu-system-x86_64 -M pc --display curses -serial mon:stdio $(OUTDIR)/image.bin
SeaBIOS (version 1.14.0-2)
[...]
Booting from Hard Disk...
Boot Stage 1
Boot Stage 2
Hello Rust !
```