# Product specification

## Purpose

The MVP proves a dependable sensor-to-result flow across two unrelated clocks.
It accepts eight-bit samples over SPI mode 0, crosses them safely, transfers them
without CPU byte copying, stores them with single-error correction/double-error
detection, performs a signed dot product, and reports completion.

## Clock and reset contract

- `sys_clk` runs the CPU, memory, DMA, accelerator, interrupt controller and UART.
- `spi_sclk` is unrelated to `sys_clk`; no frequency or phase relationship is assumed.
- `arst_n` asserts asynchronously. `sys_rst_n` and `spi_rst_n` deassert only after
  two local rising clock edges.
- The SPI master must provide at least two idle SCLK rising edges after external
  reset release and before asserting chip select. This is explicit protocol setup.

## Input contract

- SPI mode 0: MOSI is stable before each SCLK rising edge.
- `spi_cs_n=0` frames data. A byte is produced after eight sampled bits, MSB first.
- The receiver has no MISO/control response. If the FIFO is full, a received byte
  causes an overflow event and is not stored.

## CPU and firmware contract

The control core resets to PC `0x0000_0000`. Instruction ROM is read-only and
separate from the data bus. The supplied program uses LUI, ADDI, ANDI, LW, SW, BEQ
and EBREAK. Data requests remain asserted until `ready`; an error halts the core
and raises `fault`.

IRQ is a verified external observation. The MVP CPU has no `mstatus`, `mie`, `mtvec`,
`mepc`, trap entry or `mret`, so software polls status registers.

## DMA contract

- Length is 1–65535 bytes. A zero-length START is ignored.
- Each accepted FIFO byte becomes one zero-extended 32-bit SRAM word.
- Destination increments by four bytes per sample.
- Exactly one FIFO pop may be outstanding.
- DONE is sticky until cleared or a new transfer starts.
- An uncorrectable memory response stops the transfer and sets ERROR.

## ECC memory contract

- Capacity: 256 words × 32 data bits at `0x1000_0000–0x1000_03FF`.
- Aligned in-range CPU accesses complete; misaligned/out-of-range accesses fault.
- Six Hamming parity bits plus one overall parity bit form a 39-bit codeword.
- A single codeword-bit error returns corrected data and pulses `corrected`.
- A detected double-bit error pulses `uncorrectable`; consumers must reject it.
- Byte writes perform decode–merge–encode.
- CPU write wins if CPU and engine attempt writes in the same cycle, and collision
  is asserted. The architecture sequences engines to prevent that case.
- The simulation-only fault-injection port is used only while normal memory
  clients are idle in the canonical flow. If it overlaps a request, both clients
  are backpressured for the injection cycle so no acknowledged access is lost.

## Accelerator contract

For `length=N`, the engine calculates:

\[
  result = \sum_{i=0}^{N-1} signed(memory[base+4i][7:0])\times W[i\bmod8]
\]

where `W={1,-1,2,-2,3,-3,4,-4}`. Accumulation is signed 32-bit two's-complement;
overflow wraps. The demo uses eight small operands and cannot overflow.

## Acceptance criteria

The canonical test passes only if it observes DMA done, accelerator done, enabled
IRQ, correctable ECC, result `-10`, exact UART `PASS\n`, no uncorrectable ECC, no
CPU fault, and CPU halt before the timeout.
