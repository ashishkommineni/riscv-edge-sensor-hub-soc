# Interview guide

## Two-minute explanation

I treated the design as one end-to-end data-integrity problem. Sensor bits arrive
on an unrelated SPI clock, so the receive side writes bytes into an asynchronous
FIFO using local binary pointers and crosses only Gray pointers. Firmware running
on a small RV32I control core programs DMA. DMA pops one registered FIFO item at a
time and writes it into SECDED SRAM. A signed INT8 engine reads the samples and
calculates a deterministic dot product. I inject a data-bit fault after DMA; SECDED
corrects it, an interrupt source records it, and the result remains minus ten. A
self-checking test requires DMA completion, accelerator completion, IRQ, ECC
correction, exact result and exact UART output.

## Likely follow-ups

**Why not synchronize the eight-bit data bus directly?**  Independent bit
synchronizers do not preserve word coherency. The FIFO stores data in one domain
and crosses encoded pointer state.

**Why Gray code?**  Only one bit changes between adjacent pointers, reducing the
chance that the destination samples a multi-bit transitional value. It does not
remove metastability; the Gray bits still pass through synchronizer flops.

**Why does DMA wait in a separate state after asserting read enable?**  FIFO output
is registered. Holding read enable until `valid` would issue another pop on the
next clock, so request and response phases are separated.

**What can SECDED guarantee?**  Any single codeword-bit error is corrected and any
double-bit error is detected. It cannot promise detection of all higher-order
faults, and it does not solve address/control corruption.

**Why does the CPU poll if there is an interrupt controller?**  IRQ generation and
mask/pending behavior are verified, but the MVP CPU deliberately omits privileged
CSRs and trap entry. Claiming an ISR without `mtvec/mepc/mret` would be inaccurate.

**What would you improve first?**  Add ISA compliance testing or integrate a
licensed core, add parameterized accelerator coefficients, negative/reset tests,
formal FIFO/ECC properties, CDC/RDC sign-off, and archived Xcelium coverage.
