OUTDIR = target/x86_64-unknown-none/release

.PHONY: all clean run $(OUTDIR)/kernel

all: $(OUTDIR)/image.bin

clean:
	rm -f $(OUTDIR)/image.bin $(OUTDIR)/kernel.bin $(OUTDIR)/kernel.o
	cargo clean

$(OUTDIR)/image.bin: $(OUTDIR)/kernel.bin
	nasm -w+error -i src/ -i $(OUTDIR)/ -o $@ src/boot.asm

$(OUTDIR)/kernel.bin: $(OUTDIR)/kernel
	objcopy -O binary $< $@

# produce an ELF executable
$(OUTDIR)/kernel:
	cargo rustc --target=x86_64-unknown-none --release -- -C relocation-model=static

run: all
	qemu-system-x86_64 -M pc --display curses -serial mon:stdio $(OUTDIR)/image.bin
