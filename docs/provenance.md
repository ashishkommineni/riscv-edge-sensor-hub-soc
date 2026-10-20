# Provenance and reuse boundary

The RTL, Python models, firmware image generator, testbench, documentation and SVG
assets in this repository are original educational work under MIT terms. The
project does not vendor Ibex, PicoRV32, VeeR EL2, a vendor SRAM, or another external
core. No external repository history is rewritten or represented as original work.

The CPU is a deliberately small RV32I control implementation and is not presented
as ISA-compliant. To use a production-quality core, replace it behind the current
instruction/data interfaces and preserve the selected core's license, notices,
pinned commit, integration documentation, compliance results and security guidance.

Similarly, replace `ecc_sram.sv` with a target memory macro wrapper for ASIC/FPGA
implementation and prove wrapper equivalence. Preserve tool-generated evidence
outside source directories and never label a portable behavioral run as silicon
sign-off.
