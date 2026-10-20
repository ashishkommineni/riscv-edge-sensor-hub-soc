# Verification report

## Reproducible release evidence

| Check | Status | Reproduce |
|---|---|---|
| Firmware image matches generator | PASS, 35 words | `python3 scripts/build_firmware.py --check` |
| Firmware/MMIO reference execution | PASS, result `-10`, UART `PASS`, IRQ mask `0x1f` | `python3 scripts/reference_model.py` |
| SECDED reference fault campaign | PASS, 195 single-bit corrections + 5 double-bit detections | `python3 scripts/reference_model.py` |
| Repository structure gate | PASS, 16 portable RTL/TB files | `python3 scripts/structure_check.py` |
| Verilator lint | PASS in GitHub Actions | `make lint` |
| Verilator end-to-end simulation | PASS: result/UART/DMA/accelerator/IRQ/ECC gates | `make sim` |
| ECC dual-writer contention test | PASS: CPU write preserved, engine retried | `make sim-contention` |
| Xcelium UVM 1.2 | Not executed | `make xcelium` |
| IMC coverage | Not generated | Run after Xcelium regression |
| CDC/RDC sign-off | Not executed | Target technology/tool required |

## Required run record

When a simulator run is made, append—not overwrite—the following:

```text
Date:
Git commit:
Tool and version:
Command:
Test:
Seed:
Result:
UVM_ERROR/UVM_FATAL:
Assertions passed/failed:
Functional coverage:
Code coverage:
Transcript/artifact path:
Known waivers:
```

## Captured portable release run

The public [GitHub Actions run 39377346961](https://github.com/ashishkommineni/riscv-edge-sensor-hub-soc/actions/runs/39377346961)
completed successfully on 2026-10-20 with Verilator 5.020. Its relevant output
was:

```text
PASS reference model: firmware=35_words uart=PASS result=-10 irq_mask=0x1f
PASS SECDED model: clean + 195 single-bit corrections + 5 double-bit detections
SOC_TEST_PASS result=-10 uart=PASS dma=1 acc=1 irq=1 ecc_corrected=1 cycles=215
ECC_CONTENTION_TEST_PASS cpu_write=preserved engine_write=retried
```

The cycle count is evidence for this commit and test configuration, not an
architectural latency guarantee. The Xcelium/UVM and sign-off rows remain
explicitly unverified rather than inheriting the portable Verilator result.
